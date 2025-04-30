import 'package:flutter/material.dart';
import '../campground_data.dart';

class BookmarkScreen extends StatelessWidget {
  final Map<String, bool> bookmarked;
  final void Function(String name) onToggleBookmark;

  const BookmarkScreen({super.key, required this.bookmarked, required this.onToggleBookmark});

  @override
  Widget build(BuildContext context) {
    final bookmarkedCamps = campgroundList.where((camp) => bookmarked[camp['name']] == true).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('북마크')),
      body: bookmarkedCamps.isEmpty
          ? const Center(child: Text('북마크한 캠핑장이 없습니다.'))
          : ListView.builder(
        itemCount: bookmarkedCamps.length,
        itemBuilder: (context, index) {
          final camp = bookmarkedCamps[index];
          final name = camp['name'];

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.park, color: Colors.teal),
              title: Text(name),
              subtitle: Text('${camp['location']} | ${camp['type']}'),
              trailing: IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () {
                  onToggleBookmark(name); // 북마크 해제
                },
              ),
              onTap: () {
                Navigator.pushNamed(context, '/camping_info');
              },
            ),
          );
        },
      ),
    );
  }
}
