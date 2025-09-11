import 'package:camping/screens/place_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../repositories/camp_map_repository.dart';
import '../services/map_html_service.dart';
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
  static const _defaultLat = 36.1190;
  static const _defaultLng = 128.3446;

  final _repo = CampMapRepository();
  final _html = MapHtmlService();
  final _searchCtrl = TextEditingController();

  InAppWebViewController? _web;
  bool _webReady = false;

  double? _lat, _lng;
  List<Camp> _camps = [], _filtered = [];
  List<Camp> _suggestions = [];

  String? _openCampId;
  bool _detailOpen = false;

  @override
  void initState() {
    super.initState();
    _init();
    _searchCtrl.addListener(_updateSuggestions);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_updateSuggestions);
    _searchCtrl.dispose();
    super.dispose();
  }

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
      _suggestions.clear();
    });
    _reload();
  }

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
      _suggestions = matches.take(5).toList();
    });
  }

  String _injectClusterBoldCss(String html) {
    const css = '''
<style>
  .marker-cluster div, .marker-cluster span { font-weight: 700 !important; }
  .cluster-text { font-weight: 700 !important; }
</style>
''';
    if (html.contains('</head>')) {
      return html.replaceFirst('</head>', '$css</head>');
    }
    return '$css$html';
  }

  void _reload() {
    if (_lat == null || _lng == null || !_webReady || _web == null) return;
    String html = _html.interactiveMapHtml(
      lat: _lat!,
      lng: _lng!,
      camps: _filtered,
      date: widget.selectedDate,
    );
    html = _injectClusterBoldCss(html);
    _web!.loadData(data: html, mimeType: 'text/html', encoding: 'utf-8');
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => PlaceSearchScreen(
                        onLocationChange: (placeName, lat, lng) {
                          // 필요하다면 위치 변경 로직 연결
                          setState(() {
                            _lat = lat;
                            _lng = lng;
                          });
                          _reload();
                        },
                      ),
                ),
              );
            },
          ),
        ],
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
                    _webReady = true;
                    _reload();
                    c.addJavaScriptHandler(
                      handlerName: 'detail',
                      callback: (args) async {
                        final cid =
                            args.isNotEmpty ? args.first as String? : null;
                        if (cid == null || _camps.isEmpty) return;

                        final match = _camps.where((e) => e.contentId == cid);
                        if (match.isEmpty) return;
                        final camp = match.first;

                        if (_detailOpen && _openCampId == cid) {
                          if (mounted) Navigator.of(context).pop();
                          _detailOpen = false;
                          _openCampId = null;
                          return;
                        }
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
                        if (!mounted) return;
                        _detailOpen = false;
                        _openCampId = null;
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
