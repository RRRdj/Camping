import 'package:flutter/material.dart';
import '../models/place.dart';

/// 북마크/홈 설정 모달 시트
class PlaceBookmarkSheet extends StatefulWidget {
  final List<Place> initialBookmarks;
  final Place? initialHome;

  /// 별(북마크) 토글 시 실행: 저장/해제 같은 영속화 로직은 부모에서 처리
  final Future<void> Function(Place place) onToggleBookmark;

  /// 집 아이콘 클릭 시 실행: 실제 홈 저장과 위치 변경 콜백 등은 부모에서 처리
  final Future<void> Function(Place place) onSetHome;

  const PlaceBookmarkSheet({
    super.key,
    required this.initialBookmarks,
    required this.initialHome,
    required this.onToggleBookmark,
    required this.onSetHome,
  });

  @override
  State<PlaceBookmarkSheet> createState() => _PlaceBookmarkSheetState();
}

class _PlaceBookmarkSheetState extends State<PlaceBookmarkSheet> {
  late List<Place> _bookmarks;
  Place? _home;

  @override
  void initState() {
    super.initState();
    _bookmarks = List<Place>.from(widget.initialBookmarks);
    _home = widget.initialHome;
  }

  bool _isBookmarked(Place p) => _bookmarks.any((b) => b.name == p.name);
  bool _isHome(Place p) => _home != null && _home!.name == p.name;

  @override
  Widget build(BuildContext context) {
    if (_bookmarks.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('저장된 북마크가 없습니다')),
        ),
      );
    }

    return SafeArea(
      child: ListView.separated(
        itemCount: _bookmarks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = _bookmarks[i];
          final home = _isHome(p);

          return ListTile(
            title: Text(p.name),
            subtitle: Text(
              p.address ?? '',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 별(북마크) 토글
                IconButton(
                  icon: const Icon(Icons.star, color: Colors.amber),
                  onPressed: () async {
                    await widget.onToggleBookmark(p);
                    setState(() {
                      // 로컬 상태도 동기화
                      if (_isBookmarked(p)) {
                        _bookmarks.removeWhere((b) => b.name == p.name);
                      } else {
                        _bookmarks.add(p);
                      }
                    });
                  },
                ),
                // 집 설정
                IconButton(
                  icon: Icon(
                    home ? Icons.home : Icons.home_outlined,
                    color: home ? Colors.teal : Colors.grey,
                  ),
                  onPressed: () async {
                    await widget.onSetHome(p);
                    setState(() => _home = p);
                  },
                ),
              ],
            ),
            // 항목 전체 터치는 동작 없음(기획 유지)
          );
        },
      ),
    );
  }
}
