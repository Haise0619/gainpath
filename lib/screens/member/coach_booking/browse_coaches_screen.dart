import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import 'booking_schedule_screen.dart';
import 'coach_profile_screen.dart';
import 'widgets/coach_card.dart';

enum _SortBy { rating, priceLow, experience }

/// AD-M7.1 — Browse Professional Coaches. Search, specialty filter, and
/// sort share one toolbar so narrowing the list to "the one coach I
/// want" takes a couple of taps rather than scrolling the whole roster.
class BrowseCoachesScreen extends StatefulWidget {
  const BrowseCoachesScreen({super.key});

  @override
  State<BrowseCoachesScreen> createState() => _BrowseCoachesScreenState();
}

class _BrowseCoachesScreenState extends State<BrowseCoachesScreen> {
  String _specialtyFilter = 'All';
  _SortBy _sortBy = _SortBy.rating;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final specialties = ['All', ...{for (final c in MockData.coaches) c.specialty}];

    var visible = MockData.coaches.where((c) {
      final matchesSpecialty = _specialtyFilter == 'All' || c.specialty == _specialtyFilter;
      final q = _query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.specialty.toLowerCase().contains(q) ||
          c.specializationTags.any((t) => t.toLowerCase().contains(q));
      return matchesSpecialty && matchesQuery;
    }).toList();

    switch (_sortBy) {
      case _SortBy.rating:
        visible.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _SortBy.priceLow:
        visible.sort((a, b) => a.fee.compareTo(b.fee));
        break;
      case _SortBy.experience:
        visible.sort((a, b) => b.yearsExperience.compareTo(a.yearsExperience));
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coaches'),
        actions: [
          PopupMenuButton<_SortBy>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            initialValue: _sortBy,
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: _SortBy.rating, child: Text('Highest rated')),
              PopupMenuItem(value: _SortBy.priceLow, child: Text('Price: low to high')),
              PopupMenuItem(value: _SortBy.experience, child: Text('Most experienced')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.event_note_rounded),
            tooltip: 'My bookings',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BookingScheduleScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search coaches or specialties',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: specialties.map((s) {
                final selected = s == _specialtyFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: selected,
                    onSelected: (_) => setState(() => _specialtyFilter = s),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: const BorderSide(color: AppColors.hairline),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 40, color: AppColors.hairline),
                          const SizedBox(height: 14),
                          Text('No coaches match that search.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: visible
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: CoachCard(
                                coach: c,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => CoachProfileScreen(coach: c))),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
