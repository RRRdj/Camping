import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/camp_repository.dart';
import '../models/camp_with_availability.dart';
import 'camping_info_screen.dart';

class CampingHomeScreen extends StatefulWidget {
  final Map<String, bool> bookmarked;
  final void Function(String name) onToggleBookmark;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const CampingHomeScreen({
    Key? key,
    required this.bookmarked,
    required this.onToggleBookmark,
    required this.selectedDate,
    required this.onDateChanged,
  }) : super(key: key);

  @override
  State<CampingHomeScreen> createState() => _CampingHomeScreenState();
}

class _CampingHomeScreenState extends State<CampingHomeScreen> {
  final _repo = CampRepository();

  String? _keyword, _region, _type, _duty, _env, _amenity;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('MM월 dd일').format(widget.selectedDate);

    return Scaffold(
      appBar: AppBar(title: const Text('캠핑장 목록'), centerTitle: true),
      body: Column(
        children: [
          /* 날짜 Chip */
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: GestureDetector(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: widget.selectedDate,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 14)),
                );
                if (picked != null) widget.onDateChanged(picked);
              },
              child: Chip(
                avatar: const Icon(Icons.calendar_today, color: Colors.white),
                label: Text(
                  dateLabel,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.teal,
              ),
            ),
          ),
          /* 검색창 */
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: '검색어',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
          /* 리스트 */
          Expanded(
            child: StreamBuilder<List<CampWithAvailability>>(
              stream: _repo.campWithAvailStream(widget.selectedDate),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var camps = snap.data!;

                /* --- 필터링 --- */
                camps =
                    camps.where((c) {
                      final name = (c.camp['name'] as String).toLowerCase();
                      if (_keyword != null &&
                          _keyword!.isNotEmpty &&
                          !name.contains(_keyword!.toLowerCase())) {
                        return false;
                      }
                      if (_region != null &&
                          (c.camp['location'] as String).split(' ').first !=
                              _region)
                        return false;
                      if (_type != null && c.camp['type'] != _type)
                        return false;
                      if (_duty != null &&
                          !(c.camp['inDuty'] as String? ?? '')
                              .split(',')
                              .contains(_duty))
                        return false;
                      if (_env != null &&
                          (c.camp['lctCl'] as String? ?? '') != _env)
                        return false;
                      if (_amenity != null &&
                          !(c.camp['amenities'] as List<dynamic>? ?? [])
                              .contains(_amenity)) {
                        return false;
                      }
                      return true;
                    }).toList();

                /* 가나다 순 정렬 */
                camps.sort(
                  (a, b) => (a.camp['name'] as String).compareTo(
                    b.camp['name'] as String,
                  ),
                );

                if (camps.isEmpty) {
                  return const Center(
                    child: Text(
                      '검색결과가 없습니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: camps.length,
                  itemBuilder: (_, i) {
                    final c = camps[i];
                    return _CampCard(
                      camp: c,
                      isBookmarked: widget.bookmarked[c.camp['name']] == true,
                      onToggleBookmark: widget.onToggleBookmark,
                      selectedDate: widget.selectedDate,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------- CampCard ---------------------------- */
class _CampCard extends StatelessWidget {
  final CampWithAvailability camp;
  final bool isBookmarked;
  final void Function(String) onToggleBookmark;
  final DateTime selectedDate;

  const _CampCard({
    required this.camp,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final c = camp.camp;
    final avail = camp.available;
    final total = camp.total;

    return Opacity(
      opacity: camp.isAvailable ? 1 : 0.4,
      child: InkWell(
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => CampingInfoScreen(
                      campName: c['name'],
                      available: avail,
                      total: total,
                      isBookmarked: isBookmarked,
                      onToggleBookmark: onToggleBookmark,
                      selectedDate: selectedDate,
                    ),
              ),
            ),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (c['firstImageUrl'] != null &&
                    (c['firstImageUrl'] as String).isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      c['firstImageUrl'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const Icon(Icons.park, size: 48, color: Colors.teal),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${c['location']} | ${c['type']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        camp.isAvailable
                            ? '예약 가능 ($avail/$total)'
                            : '예약 마감 ($avail/$total)',
                        style: TextStyle(
                          color: camp.isAvailable ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked ? Colors.red : Colors.grey,
                  ),
                  onPressed: () => onToggleBookmark(c['name']),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
