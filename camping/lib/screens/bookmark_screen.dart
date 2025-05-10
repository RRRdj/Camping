import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../campground_data.dart';
import 'camping_info_screen.dart';

class BookmarkScreen extends StatefulWidget {
  final Map<String, bool> bookmarked;
  final void Function(String name) onToggleBookmark;

  const BookmarkScreen({
    super.key,
    required this.bookmarked,
    required this.onToggleBookmark,
  });

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    final bookmarkedCamps = campgroundList
        .where((camp) => widget.bookmarked[camp['name']] == true)
        .toList();

    if (bookmarkedCamps.isEmpty) {
      return const Center(child: Text('북마크한 캠핑장이 없습니다.'));
    }

    final key = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return ListView.builder(
      itemCount: bookmarkedCamps.length,
      itemBuilder: (_, i) {
        final camp = bookmarkedCamps[i];
        final name = camp['name'] as String;
        final location = camp['location'];
        final type = camp['type'];

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('realtime_availability')
              .doc(name)
              .get(),
          builder: (context, snap1) {
            final data = snap1.data?.data();
            final available = data?[key]?['available'] ?? 0;
            final total = data?[key]?['total'] ?? 0;
            final isAvail = available > 0;

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('campgrounds')
                  .doc(name)
                  .get(),
              builder: (context, snap2) {
                final img = snap2.data?.data()?['firstImageUrl'] ?? '';
                final hasImage = img.toString().isNotEmpty;

                return Opacity(
                  opacity: isAvail ? 1 : 0.4,
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: hasImage
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          img,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                          : const Icon(Icons.park,
                          size: 48, color: Colors.teal),
                      title: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$location | $type',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            isAvail
                                ? '예약 가능 ($available/$total)'
                                : '예약 마감 ($available/$total)',
                            style: TextStyle(
                                fontSize: 12,
                                color: isAvail ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold),
                          )
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        onPressed: () {
                          widget.onToggleBookmark(name);
                          setState(() {});
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CampingInfoScreen(
                              campName: name,
                              available: available,
                              total: total,
                              isBookmarked:
                              widget.bookmarked[name] == true,
                              onToggleBookmark: widget.onToggleBookmark,
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
