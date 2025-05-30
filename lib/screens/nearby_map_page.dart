import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
  final _repo = CampMapRepository();
  final _html = CampMapHtmlService();
  final _searchCtrl = TextEditingController();
  late InAppWebViewController _web;
  double? _lat, _lng;
  List<Camp> _camps = [], _filtered = [];

  @override
  void initState() {
    super.initState();
    _init();
    _searchCtrl.addListener(_search);
  }

  Future<void> _init() async {
    try {
      final pos = await _repo.currentPosition();
      final camps = await _repo.fetchCamps(widget.selectedDate);
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _camps = camps;
        _filtered = List.from(camps);
      });
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

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
    });
    _reload();
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
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '캠핑장명 또는 지역 검색',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: InAppWebView(
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
                    final camp = _camps.firstWhere((e) => e.contentId == cid);
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
          ),
        ],
      ),
    );
  }
}
