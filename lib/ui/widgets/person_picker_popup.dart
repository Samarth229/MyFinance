import 'package:flutter/material.dart';
import '../../core/models/person.dart';
import '../../core/repositories/person_repository.dart';
import '../theme/app_theme.dart';

class PersonAssignment {
  Person person;
  double quantity;
  bool onlyOnce;
  PersonAssignment({required this.person, this.quantity = 1, this.onlyOnce = false});
}

Future<List<PersonAssignment>?> showPersonPickerPopup(
  BuildContext context, {
  List<PersonAssignment> existing = const [],
}) {
  return showDialog<List<PersonAssignment>>(
    context: context,
    builder: (_) => PersonPickerPopup(existing: existing),
  );
}

Future<PersonPickerResult?> showPersonPickerWithSelf(
  BuildContext context, {
  List<PersonAssignment> existing = const [],
  bool selfSelected = false,
}) {
  return showDialog<PersonPickerResult>(
    context: context,
    builder: (_) => PersonPickerPopup(
      existing: existing,
      allowSelf: true,
      selfSelected: selfSelected,
    ),
  );
}

class PersonPickerResult {
  final List<PersonAssignment> assignments;
  final bool selfIncluded;
  const PersonPickerResult(this.assignments, {this.selfIncluded = false});
}

class PersonPickerPopup extends StatefulWidget {
  final List<PersonAssignment> existing;
  final bool allowSelf;
  final bool selfSelected;
  const PersonPickerPopup({
    super.key,
    this.existing = const [],
    this.allowSelf = false,
    this.selfSelected = false,
  });

  @override
  State<PersonPickerPopup> createState() => _PersonPickerPopupState();
}

class _PersonPickerPopupState extends State<PersonPickerPopup> {
  final _repo = PersonRepository();
  final _searchController = TextEditingController();

  List<Person> _allPersons = [];
  List<Person> _filtered = [];
  final Map<String, PersonAssignment> _selected = {};
  bool _selfIncluded = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selfIncluded = widget.selfSelected;
    for (final a in widget.existing) {
      final key = a.person.id?.toString() ?? a.person.name;
      _selected[key] = PersonAssignment(person: a.person, quantity: a.quantity);
    }
    _searchController.addListener(_filter);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final persons = await _repo.getAllPersons();
    setState(() {
      _allPersons = persons;
      _loading = false;
    });
    _filter();
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_allPersons)
          : _allPersons.where((p) => p.name.toLowerCase().contains(q)).toList();
    });
  }

  void _toggle(Person p) {
    final key = p.id?.toString() ?? p.name;
    setState(() {
      if (_selected.containsKey(key)) {
        _selected.remove(key);
      } else {
        _selected[key] = PersonAssignment(person: p, quantity: 1);
      }
    });
  }

  Future<void> _showAddPersonDialog() async {
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Person',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Enter person name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final newPerson =
                        Person(name: name, createdAt: DateTime.now());
                    setState(() {
                      _selected[name] = PersonAssignment(
                          person: newPerson, quantity: 1, onlyOnce: true);
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Only Once'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    // Check if already exists
                    final exists = _allPersons.any((p) =>
                        p.name.toLowerCase() == name.toLowerCase());
                    Person person;
                    if (exists) {
                      person = _allPersons.firstWhere((p) =>
                          p.name.toLowerCase() == name.toLowerCase());
                    } else {
                      // Save to DB
                      person = Person(name: name, createdAt: DateTime.now());
                      final id = await _repo.insertPerson(person);
                      person = Person(
                          id: id, name: name, createdAt: DateTime.now());
                      if (!ctx.mounted) return;
                      setState(() {
                        _allPersons.add(person);
                      });
                      _filter();
                    }
                    final key = person.id?.toString() ?? person.name;
                    if (!ctx.mounted) return;
                    setState(() {
                      _selected[key] =
                          PersonAssignment(person: person, quantity: 1);
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Update Contact'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _update() {
    if (widget.allowSelf) {
      Navigator.pop(
        context,
        PersonPickerResult(_selected.values.toList(), selfIncluded: _selfIncluded),
      );
    } else {
      Navigator.pop(context, _selected.values.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Title
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Assign People',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            // Row 2: Add Person + Self buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showAddPersonDialog,
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Add Person'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  if (widget.allowSelf) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selfIncluded = !_selfIncluded),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _selfIncluded
                                ? AppTheme.success.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selfIncluded
                                  ? AppTheme.success
                                  : Colors.grey.shade400,
                              width: _selfIncluded ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selfIncluded
                                    ? Icons.check_circle
                                    : Icons.person_outline,
                                color: AppTheme.success,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text('Self',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.success,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Row 3: Search + Done
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search people...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _update,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(72, 44)),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Person list
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final p = _filtered[i];
                        final key = p.id?.toString() ?? p.name;
                        final isSelected = _selected.containsKey(key);
                        final assignment = _selected[key];

                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: isSelected
                                ? AppTheme.primary
                                : AppTheme.primary.withValues(alpha: 0.12),
                            child: Text(
                              p.name[0].toUpperCase(),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          title: Text(p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          trailing: isSelected
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Qty:',
                                        style: TextStyle(fontSize: 12)),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 50,
                                      child: TextField(
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 4),
                                            border: OutlineInputBorder()),
                                        controller: TextEditingController(
                                            text: assignment!.quantity
                                                .toString()),
                                        onChanged: (v) {
                                          final qty = double.tryParse(v);
                                          if (qty != null && qty > 0) {
                                            assignment.quantity = qty;
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                          onTap: () => _toggle(p),
                          selected: isSelected,
                          selectedTileColor:
                              AppTheme.primary.withValues(alpha: 0.05),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
