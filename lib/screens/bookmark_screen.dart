import 'package:flutter/material.dart';
import '../campground_data.dart';
import 'camping_info_screen.dart';
import '../repositories/real_time_availability_repository.dart';
import '../repositories/campground_repository.dart';
import '../services/camp_util_service.dart';

class BookmarkScreen extends StatefulWidget {
  final Map<String, bool> bookmarked;
  final void Function(String name) onToggleBookmark;
  final DateTime selectedDate;

  const BookmarkScreen({
    super.key,
    required this.bookmarked,
    required this.onToggleBookmark,
    required this.selectedDate,
  });

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  final _availRepo = RealTimeAvailabilityRepository();
  final _campRepo = CampgroundRepository();
  final _util = CampUtilService();

  @override
  Widget build(BuildContext context) {
    final bookmarkedCamps =
        campgroundList
            .where((camp) => widget.bookmarked[camp['name']] == true)
            .toList();

    if (bookmarkedCamps.isEmpty) {
      return const Center(child: Text('북마크한 캠핑장이 없습니다.'));
    }

    final dateKey = _util.formatDateKey(widget.selectedDate);

    return ListView.builder(
      itemCount: bookmarkedCamps.length,
      itemBuilder: (_, i) {
        final camp = bookmarkedCamps[i];
        final name = camp['name'] as String;
        final location = camp['location'];
        final type = camp['type'];

        return FutureBuilder<Availability>(
          future: _availRepo.fetchAvailability(
            campName: name,
            dateKey: dateKey,
          ),
          builder: (context, snap1) {
            final availData = snap1.data;
            final available = availData?.available ?? 0;
            final total = availData?.total ?? 0;
            final isAvail = available > 0;

            return FutureBuilder<Campground>(
              future: _campRepo.fetchCampground(name),
              builder: (context, snap2) {
                final img = snap2.data?.firstImageUrl ?? '';
                final hasImage = img.isNotEmpty;

                return Opacity(
                  opacity: isAvail ? 1 : 0.4,
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading:
                          hasImage
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  img,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                              : const Icon(
                                Icons.park,
                                size: 48,
                                color: Colors.teal,
                              ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$location | $type',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isAvail
                                ? '예약 가능 ($available/$total)'
                                : '예약 마감 ($available/$total)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isAvail ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.bookmark, color: Colors.red),
                        onPressed: () {
                          widget.onToggleBookmark(name);
                          setState(() {});
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => CampingInfoScreen(
                                  campName: name,
                                  available: available,
                                  total: total,
                                  isBookmarked: widget.bookmarked[name] == true,
                                  onToggleBookmark: widget.onToggleBookmark,
                                  selectedDate: widget.selectedDate,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
