import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';

import '../repositories/camp_map_repository.dart';
import '../services/camp_map_html_service.dart';
import 'camping_info_screen.dart';

class NearbyMapPage extends StatefulWidget {
  final Map<String, bool> bookmarked;
  final void Function(String campName) onToggleBookmark;
  final DateTime selectedDate;

  const NearbyMapPage({
    super.key,
    required this.bookmarked,
    required this.onToggleBookmark,
    required this.selectedDate,
  });

  @override
  State<NearbyMapPage> createState() => _NearbyMapPageState();
}

class _NearbyMapPageState extends State<NearbyMapPage> {
  // 구미시 기준 좌표
  static const _defaultLat = 36.1190;
  static const _defaultLng = 128.3446;

  final _repo = CampMapRepository();
  final _html = CampMapHtmlService();
  final _searchCtrl = TextEditingController();
  late InAppWebViewController _web;

  double? _lat, _lng;
  List<Camp> _camps = [], _filtered = [];
  // 입력 중 추천 리스트
  List<Camp> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _init();
    // 입력 중 추천 목록 업데이트
    _searchCtrl.addListener(_updateSuggestions);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_updateSuggestions);
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 초기화: 기본 좌표(구미) + 캠핑장 데이터 로드
  Future<void> _init() async {
    final camps = await _repo.fetchCamps(widget.selectedDate);
    if (!mounted) return;
    setState(() {
      _lat = _defaultLat;
      _lng = _defaultLng;
      _camps = camps;
      _filtered = List.from(camps);
    });
  }

  /// '내 위치' 버튼 동작
  Future<void> _moveToCurrentLocation() async {
    try {
      final pos = await _repo.currentPosition();
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _reload();
    } catch (_) {}
  }

  /// 검색 버튼 누를 때 호출
  void _search() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered =
          q.isEmpty
              ? List.from(_camps)
              : _camps
                  .where(
                    (c) =>
                        c.name.toLowerCase().contains(q) ||
                        c.region.toLowerCase().contains(q),
                  )
                  .toList();
      _suggestions.clear(); // 검색 시 추천 목록 숨김
    });
    _reload();
  }

  /// 입력 중 캠핑장 이름/지역 추천
  void _updateSuggestions() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _suggestions.clear());
      return;
    }
    final matches = _camps.where(
      (c) =>
          c.name.toLowerCase().contains(q) ||
          c.region.toLowerCase().contains(q),
    );
    setState(() {
      _suggestions = matches.take(5).toList(); // 최대 5개
    });
  }

  void _reload() {
    if (_lat == null || _lng == null) return;
    final html = _html.interactiveMapHtml(
      lat: _lat!,
      lng: _lng!,
      camps: _filtered,
      date: widget.selectedDate,
    );
    _web.loadData(data: html, mimeType: 'text/html', encoding: 'utf-8');
  }

  @override
  Widget build(BuildContext context) {
    if (_lat == null || _lng == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('내 주변 캠핑장')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: '캠핑장명 또는 지역 검색',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _search,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      child: const Icon(Icons.search),
                    ),
                  ],
                ),
                // 추천 리스트
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (context, idx) {
                        final camp = _suggestions[idx];
                        return ListTile(
                          title: Text(camp.name),
                          subtitle: Text(camp.region),
                          onTap: () {
                            // 선택한 캠핑장으로 중심 이동 후 검색
                            setState(() {
                              _lat = camp.lat;
                              _lng = camp.lng;
                              _searchCtrl.text = camp.name;
                              _suggestions.clear();
                            });
                            _search();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialData: InAppWebViewInitialData(
                    data: '<html><body>Loading…</body></html>',
                  ),
                  onWebViewCreated: (c) {
                    _web = c;
                    _reload();
                    c.addJavaScriptHandler(
                      handlerName: 'detail',
                      callback: (args) {
                        final cid = args.first as String?;
                        if (cid == null) return;
                        final camp = _camps.firstWhere(
                          (e) => e.contentId == cid,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => CampingInfoScreen(
                                  campName: cid,
                                  available: camp.available,
                                  total: camp.total,
                                  isBookmarked: widget.bookmarked[cid] ?? false,
                                  onToggleBookmark: widget.onToggleBookmark,
                                  selectedDate: widget.selectedDate,
                                ),
                          ),
                        );
                      },
                    );
                  },
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 3,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    onPressed: _moveToCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('내 위치', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
