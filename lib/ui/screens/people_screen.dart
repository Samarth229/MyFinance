import 'package:flutter/material.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/person_report.dart';
import '../../core/repositories/person_repository.dart';
import '../widgets/person_tile.dart';
import '../widgets/empty_state.dart';
import 'add_person_screen.dart';
import 'person_detail_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _analytics = AnalyticsService();
  final _personRepo = PersonRepository();

  List<PersonReport> _reports = [];
  List<PersonReport> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await _analytics.getPersonReports();
      setState(() {
        _reports = reports;
        _loading = false;
      });
      _filter();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_reports)
          : _reports
              .where((r) => r.name.toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _confirmDelete(PersonReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Person'),
        content: Text(
            'Delete ${report.name}? All their transactions will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _personRepo.deletePerson(report.personId);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search people...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Error loading people',
                  subtitle: _error,
                  actionLabel: 'Retry',
                  onAction: _load,
                )
              : _filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline,
                      title: _searchController.text.isEmpty
                          ? 'No people yet'
                          : 'No results',
                      subtitle: _searchController.text.isEmpty
                          ? 'Tap + to add someone'
                          : null,
                      actionLabel: _searchController.text.isEmpty
                          ? 'Add Person'
                          : null,
                      onAction: _searchController.text.isEmpty
                          ? () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AddPersonScreen()),
                              );
                              _load();
                            }
                          : null,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final report = _filtered[i];
                          return Dismissible(
                            key: Key('person_${report.personId}'),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              await _confirmDelete(report);
                              return false;
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete,
                                  color: Colors.white),
                            ),
                            child: PersonTile(
                              report: report,
                              onDelete: () => _confirmDelete(report),
                              onTap: () async {
                                final person = await _personRepo
                                    .getPersonById(report.personId);
                                if (!mounted) return;
                                if (person != null) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PersonDetailScreen(
                                          person: person),
                                    ),
                                  );
                                  _load();
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
