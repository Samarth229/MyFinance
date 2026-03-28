import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme/app_theme.dart';
import 'bill_items_screen.dart';

// ── Bill Parser ──────────────────────────────────────────────────────────────

class ParsedBillItem {
  String name;
  double price;
  ParsedBillItem({required this.name, required this.price});
}

// Internal helpers
class _BillLine {
  final String text;
  final double top, bottom, left, right;
  final List<TextElement> elements;
  double get midY => (top + bottom) / 2;
  double get height => bottom - top;
  _BillLine({required this.text, required this.top, required this.bottom,
      required this.left, required this.right, required this.elements});
}

class _ParseResult {
  final String name;
  final double price;
  _ParseResult(this.name, this.price);
}

class BillParser {
  // Expanded noise keyword list — contains-match on lowercase line text
  static const _noise = [
    // Totals
    'grand total', 'net total', 'net amount', 'net payable', 'bill amount',
    'total', 'subtotal', 'sub total', 'sub-total', 'payable',
    // Taxes
    'cgst', 'sgst', 'igst', 'gst', 'vat', 'cess', 'service tax', 'tax',
    // Charges & discounts
    'service charge', 'packaging charge', 'packing charge', 'carry bag',
    'discount', 'offer', 'coupon', 'promo', 'saving', 'rounding', 'round off',
    // Bill metadata
    'bill no', 'bill amount', 'inv no', 'invoice', 'receipt',
    // Table / order info
    'table no', 'table:', 'cover', 'covers', 'pax', 'seat', 'kot', 'token no',
    'order no', 'order id',
    // Column headers
    'qty', 'quantity', 'description', 'particulars', 'unit price', 'mrp',
    'sr no', 's.no', 'sl no', 'item', 'rate', 'amount',
    // Payment
    'cash', 'change due', 'balance due', 'tendered', 'paid',
    // Staff / store info
    'cashier', 'waiter', 'captain', 'server',
    'date:', 'time:', 'phone:', 'mobile:', 'tel:', 'mob:', 'ph:',
    'address', 'gstin', 'fssai', 'pan:',
    // Service mode
    'dine in', 'take away', 'takeaway', 'delivery', 'parcel',
    'swiggy', 'zomato', 'uber eats',
    // Footer
    'thank', 'welcome', 'visit again', 'come again', 'print', 'duplicate',
  ];

  /// Main entry — uses spatial (bounding box) layout from ML Kit
  static List<ParsedBillItem> parse(RecognizedText recognized) {
    // 1. Collect all TextLines with their bounding boxes
    final billLines = <_BillLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final box = line.boundingBox;
        if (box == null || line.text.trim().isEmpty) continue;
        billLines.add(_BillLine(
          text: line.text.trim(),
          top: box.top,
          bottom: box.bottom,
          left: box.left,
          right: box.right,
          elements: line.elements,
        ));
      }
    }
    if (billLines.isEmpty) return [];

    // 2. Sort top → bottom
    billLines.sort((a, b) => a.top.compareTo(b.top));

    // 3. Estimate average line height (for row-grouping threshold)
    final avgH = billLines.map((l) => l.height).reduce((a, b) => a + b) /
        billLines.length;

    // 4. Group TextLines that sit at the same vertical level into one row.
    //    This handles cases where ML Kit splits "Chicken Tikka  280.00" into
    //    two separate TextBlocks side by side.
    final List<List<_BillLine>> rows = [];
    for (final line in billLines) {
      bool merged = false;
      for (final row in rows) {
        final rowMidY =
            row.map((l) => l.midY).reduce((a, b) => a + b) / row.length;
        if ((line.midY - rowMidY).abs() < avgH * 0.65) {
          row.add(line);
          merged = true;
          break;
        }
      }
      if (!merged) rows.add([line]);
    }

    // 5. Parse rows top → bottom
    final items = <ParsedBillItem>[];
    String? pendingName; // buffers multi-line item names (prefix for next item)
    double lastItemBottomY = -9999;

    for (final row in rows) {
      // Sort lines within each row left → right
      row.sort((a, b) => a.left.compareTo(b.left));
      final rowText = row.map((l) => l.text).join(' ').trim();
      final rowTopY = row.map((l) => l.top).reduce((a, b) => a < b ? a : b);
      final rowBottomY = row.map((l) => l.bottom).reduce((a, b) => a > b ? a : b);

      if (_isNoise(rowText)) {
        pendingName = null;
        lastItemBottomY = -9999;
        continue;
      }

      final result = _extractNamePrice(row);

      if (result != null) {
        var name = result.name;
        // Prepend any buffered multi-line name fragment
        if (pendingName != null) {
          name = '$pendingName $name'.trim();
          pendingName = null;
        }
        name = _clean(name);
        if (name.length >= 2 && result.price >= 5 && result.price <= 50000) {
          items.add(ParsedBillItem(name: name, price: result.price));
          lastItemBottomY = rowBottomY;
        }
      } else {
        // No price on this row — could be a wrapped name continuation or a prefix
        final text = _clean(rowText);
        if (text.length >= 2 && RegExp(r'[a-zA-Z]').hasMatch(text)) {
          // If this row is vertically adjacent to the last extracted item,
          // it's a continuation of that item's name (e.g. "Masala Grilled" → "Sandwich")
          if (items.isNotEmpty && (rowTopY - lastItemBottomY) < avgH * 1.8) {
            items.last.name = '${items.last.name} $text'.trim();
            lastItemBottomY = rowBottomY;
          } else {
            // Buffer as prefix for the next item
            pendingName = pendingName == null ? text : '$pendingName $text';
            if (pendingName.split(' ').length > 7) pendingName = null;
          }
        }
      }
    }

    // Remove items whose name matches a known subtotal/summary label
    const subtotalNames = {'sub', 'total', 'net', 'balance', 'payable', 'amount'};
    items.removeWhere((item) => subtotalNames.contains(item.name.toLowerCase()));

    return items;
  }

  // ── Spatial price extraction ───────────────────────────────────────────────

  static _ParseResult? _extractNamePrice(List<_BillLine> row) {
    // Gather all elements from all lines in this row, sorted left → right
    final elems = <TextElement>[];
    for (final line in row) {
      elems.addAll(line.elements);
    }
    elems.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    if (elems.isEmpty) return null;

    // Scan right → left to find the rightmost price-like element
    int priceIdx = -1;
    double price = 0;
    for (int i = elems.length - 1; i >= 0; i--) {
      final p = _parsePrice(elems[i].text);
      if (p != null) {
        price = p;
        priceIdx = i;
        break;
      }
    }
    if (priceIdx < 0) return null;

    // Bills often have: Name | Qty | Unit Price | Amount
    // Walk backward from the Amount column to find Unit Price column then Qty column.
    int nameEnd = priceIdx;
    double qty = 1;
    int checkIdx = priceIdx - 1;
    bool foundUnitPriceCol = false;

    // If element just before Amount is also a decimal price (>= 5), it's the Unit Price column.
    if (checkIdx >= 0) {
      final t = elems[checkIdx].text.trim();
      final v = double.tryParse(t);
      if (v != null && v >= 5 && (t.contains('.') || t.contains(','))) {
        price = v; // use per-item unit price directly
        checkIdx--;
        foundUnitPriceCol = true;
      }
    }

    // Check if the next element left is a qty integer (no decimal point)
    if (checkIdx >= 0) {
      final prevText = elems[checkIdx].text.trim();
      final prevVal = double.tryParse(prevText);
      if (prevVal != null &&
          prevVal >= 1 && prevVal <= 20 &&
          prevVal == prevVal.truncateToDouble() &&
          !prevText.contains('.') && !prevText.contains(',')) {
        nameEnd = checkIdx;
        qty = prevVal;
      }
    }

    // Only divide by qty when there was no explicit unit price column
    final unitPrice = (!foundUnitPriceCol && qty > 1) ? price / qty : price;

    String name = elems
        .sublist(0, nameEnd)
        .map((e) => e.text.trim())
        .join(' ')
        .trim();

    // Strip trailing price text that leaked into name (e.g. "150.00" at end)
    name = name.replaceFirst(RegExp(r'\s+\d+(?:[.,]\d{1,2})?\s*$'), '').trim();
    // Strip trailing lone qty integer leftover (e.g. " 2" at end)
    name = name.replaceFirst(RegExp(r'\s+\d{1,2}\s*$'), '').trim();
    // Strip leading "2x" / "2 x" quantity prefix
    name = name.replaceFirst(RegExp(r'^\d{1,2}\s*[xX×@]\s*'), '').trim();

    return name.isEmpty ? null : _ParseResult(name, unitPrice);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Parses price strings handling ₹ symbol, thousands commas, decimal commas.
  static double? _parsePrice(String raw) {
    raw = raw.trim()
        .replaceAll('₹', '')
        .replaceAll(RegExp(r'[Rr]s\.?'), '')
        .trim();
    if (raw.isEmpty) return null;
    // "1,280.00" — thousands-separator comma
    if (RegExp(r'^\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?$').hasMatch(raw)) {
      final val = double.tryParse(raw.replaceAll(',', ''));
      if (val != null && val >= 5 && val <= 50000) return val;
      return null;
    }
    // "280,00" — European decimal comma
    if (RegExp(r'^\d+,\d{2}$').hasMatch(raw)) {
      final val = double.tryParse(raw.replaceAll(',', '.'));
      if (val != null && val >= 5 && val <= 50000) return val;
      return null;
    }
    // Standard decimal or plain integer
    final val = double.tryParse(raw);
    if (val != null && val >= 5 && val <= 50000) return val;
    return null;
  }

  static bool _isNoise(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.length < 2) return true;
    // Pure number line (standalone total/amount without a name)
    if (RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(lower)) return true;
    return _noise.any((k) => lower.contains(k));
  }

  /// Strips serial numbers, OCR artifacts, and normalises whitespace.
  static String _clean(String s) => s
      .replaceFirst(RegExp(r'^\d+\s*[.):\-]?\s*'), '')
      .replaceAll(RegExp(r'[|_\\]'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

// ── Bill Scan Screen ─────────────────────────────────────────────────────────

class BillScanScreen extends StatefulWidget {
  final String type;
  final bool useGallery;
  const BillScanScreen({super.key, required this.type, this.useGallery = false});

  @override
  State<BillScanScreen> createState() => _BillScanScreenState();
}

class _BillScanScreenState extends State<BillScanScreen> {
  bool _scanning = false;
  List<ParsedBillItem>? _parsedItems;
  bool _editMode = false;

  Future<void> _scanBill() async {
    setState(() => _scanning = true);
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
          source: widget.useGallery ? ImageSource.gallery : ImageSource.camera,
          imageQuality: 90);

      if (image == null) {
        setState(() => _scanning = false);
        return;
      }

      // OCR
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognized = await recognizer.processImage(inputImage);
      await recognizer.close();

      // Auto-delete image
      final file = File(image.path);
      if (await file.exists()) await file.delete();

      final items = BillParser.parse(recognized);

      setState(() {
        _parsedItems = items;
        _scanning = false;
        _editMode = false;
      });
    } catch (e) {
      setState(() => _scanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onConfirm() {
    if (_parsedItems == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BillItemsScreen(
          type: widget.type,
          initialItems: _parsedItems!
              .map((i) => BillItemEntry(name: i.name, basePrice: i.price))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Bill')),
      body: _scanning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Extracting bill items...'),
                ],
              ),
            )
          : _parsedItems == null
              ? _buildInitial()
              : _buildConfirm(),
    );
  }

  Widget _buildInitial() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                widget.useGallery
                    ? Icons.photo_library_outlined
                    : Icons.document_scanner_outlined,
                size: 80,
                color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
                widget.useGallery
                    ? 'Select a bill photo from gallery'
                    : 'Take a photo of the bill',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Items and prices will be extracted automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _scanBill,
              icon: Icon(widget.useGallery
                  ? Icons.photo_library
                  : Icons.camera_alt),
              label: Text(
                  widget.useGallery ? 'Open Gallery' : 'Open Camera'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirm() {
    final items = _parsedItems!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text('${items.length} items extracted',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: _editMode
                        ? Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  decoration: const InputDecoration(
                                      labelText: 'Item name', isDense: true),
                                  controller: TextEditingController(
                                      text: item.name)
                                    ..selection = TextSelection.collapsed(
                                        offset: item.name.length),
                                  onChanged: (v) => items[i].name = v,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration: const InputDecoration(
                                      labelText: '₹ Price', isDense: true),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  controller: TextEditingController(
                                      text: item.price.toString()),
                                  onChanged: (v) {
                                    final p = double.tryParse(v);
                                    if (p != null) items[i].price = p;
                                  },
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                              ),
                              Text('₹${item.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ],
                          ),
                  ),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Is this correct?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _editMode = !_editMode);
                      },
                      icon: Icon(_editMode ? Icons.check : Icons.edit, size: 18),
                      label: Text(_editMode ? 'Done Editing' : 'No, Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _editMode ? null : _onConfirm,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Yes, Continue'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _scanBill,
                child: const Text('Rescan Bill'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
