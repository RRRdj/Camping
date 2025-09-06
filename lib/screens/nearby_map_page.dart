// lib/screens/nearby_map_page.dart
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

  // ▼▼▼ 상세보기 토글 상태 (요청 1번)
  String? _openCampId;
  bool _detailOpen = false;
  // ▲▲▲

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

  /// (요청 2번) 클러스터 숫자 Bold CSS 주입
  String _injectClusterBoldCss(String html) {
    const css = '''
<style>
  /* Leaflet MarkerCluster 기본 구조 대응 */
  .marker-cluster div, .marker-cluster span { 
    font-weight: 700 !important; 
  }
  /* 혹시 커스텀 클래스가 있다면 함께 대응 */
  .cluster-text { font-weight: 700 !important; }
</style>
''';
    if (html.contains('</head>')) {
      return html.replaceFirst('</head>', '$css</head>');
    }
    return '$css$html';
  }

  void _reload() {
    if (_lat == null || _lng == null) return;
    String html = _html.interactiveMapHtml(
      lat: _lat!,
      lng: _lng!,
      camps: _filtered,
      date: widget.selectedDate,
    );
    // ▼ 숫자 Bold 스타일 삽입
    html = _injectClusterBoldCss(html);
    // ▲
    _web.loadData(data: html, mimeType: 'text/html', encoding: 'utf-8');
  }

  @override
  Widget build(BuildContext context) {
    if (_lat == null || _lng == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '내 주변 캠핑장',
          style: TextStyle(
            fontWeight: FontWeight.bold, // 또는 FontWeight.w700
            fontSize: 20, // 필요하다면 크기도 조정
          ),
        ),
      ),

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
                      callback: (args) async {
                        final cid = args.first as String?;
                        if (cid == null) return;

                        // camp 찾기
                        final camp = _camps.firstWhere(
                          (e) => e.contentId == cid,
                          orElse: () => _camps.first,
                        );

                        // ▼▼ 상세보기 토글 로직 (요청 1번)
                        if (_detailOpen && _openCampId == cid) {
                          // 같은 캠프 아이콘을 다시 누르면 닫기
                          if (mounted) Navigator.of(context).pop();
                          _detailOpen = false;
                          _openCampId = null;
                          return;
                        }
                        // 다른 캠프가 열려있으면 우선 닫고 새로 열기
                        if (_detailOpen && mounted) {
                          Navigator.of(context).pop();
                          _detailOpen = false;
                          _openCampId = null;
                        }

                        _openCampId = cid;
                        _detailOpen = true;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => CampingInfoScreen(
                                  // campName은 실제 이름으로 전달하는 게 자연스럽습니다.
                                  campName: camp.name,
                                  available: camp.available,
                                  total: camp.total,
                                  isBookmarked:
                                      widget.bookmarked[camp.name] ?? false,
                                  onToggleBookmark: widget.onToggleBookmark,
                                  selectedDate: widget.selectedDate,
                                ),
                          ),
                        );
                        // 상세 화면에서 돌아오면 상태 정리
                        if (!mounted) return;
                        _detailOpen = false;
                        _openCampId = null;
                        // ▲▲
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
