import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../campground_data.dart';
import 'camping_info_screen.dart';

class CampingHomeScreen extends StatefulWidget {
  final Map<String, bool> bookmarked;
  final void Function(String name) onToggleBookmark;

  const CampingHomeScreen({
    Key? key,
    required this.bookmarked,
    required this.onToggleBookmark,
  }) : super(key: key);

  @override
  State<CampingHomeScreen> createState() => _CampingHomeScreenState();
}

class _CampingHomeScreenState extends State<CampingHomeScreen> {
  late Future<List<Map<String, dynamic>>> _mergedDataFuture;
  DateTime selectedDateObj = DateTime.now().add(const Duration(days: 1));

  // SearchPage 로부터 받은 필터링 인자들
  String _searchKeyword = '';
  List<String> _filterRegions = [];
  List<String> _filterTypes = [];

  @override
  void initState() {
    super.initState();
    _mergedDataFuture = _loadAndMergeData();
  }

  Future<String?> _fetchFallbackImage(String contentId, String serviceKey) async {
    final fallbackUrl = Uri.parse('https://apis.data.go.kr/B551011/GoCamping/imageList').replace(
      queryParameters: {
        'serviceKey': serviceKey,
        'numOfRows': '5000',
        'pageNo': '1',
        'MobileOS': 'AND',
        'MobileApp': 'camping',
        '_type': 'XML',
        'contentId': contentId,
      },
    );
    final resp = await http.get(fallbackUrl);
    if (resp.statusCode != 200) return null;
    final doc = XmlDocument.parse(utf8.decode(resp.bodyBytes));
    final elem = doc.findAllElements('imageUrl').firstWhere(
          (_) => true,
      orElse: () => XmlElement(XmlName('')),
    );
    return elem.name.local == '' ? null : elem.text.trim();
  }

  Future<List<Map<String, dynamic>>> _loadAndMergeData() async {
    const serviceKey = 'aL18yks/TuI52tnTlLaQJMx9YCVO0R+vqXjDZBmBe3ST78itxBjo6ZKJIvlWWSh2tTqkWFpbpELlGrCuKFlUaw==';
    final baseUrl = Uri.parse('https://apis.data.go.kr/B551011/GoCamping/basedList').replace(
      queryParameters: {
        'serviceKey': serviceKey,
        'numOfRows': '5000',
        'pageNo': '1',
        'MobileOS': 'AND',
        'MobileApp': 'camping',
        '_type': 'XML',
      },
    );
    final baseResp = await http.get(baseUrl);
    if (baseResp.statusCode != 200) {
      throw Exception('기본 API 오류: ${baseResp.statusCode}');
    }
    final doc = XmlDocument.parse(utf8.decode(baseResp.bodyBytes));
    final allItems = doc.findAllElements('item').map((node) {
      return {
        'facltNm': node.getElement('facltNm')?.text.trim() ?? '',
        'contentId': node.getElement('contentId')?.text.trim() ?? '',
        'firstImageUrl': node.getElement('firstImageUrl')?.text.trim() ?? '',
      };
    }).where((e) => (e['facltNm'] as String).isNotEmpty).toList();

    final merged = <Map<String, dynamic>>[];
    for (var camp in campgroundList) {
      final match = allItems.firstWhere(
            (it) => (it['facltNm'] as String).toLowerCase() == camp['name'].toString().toLowerCase(),
        orElse: () => {},
      );
      if (match.isEmpty) continue;

      String? imageUrl = match['firstImageUrl'] as String?;
      if (imageUrl == null || imageUrl.isEmpty) {
        imageUrl = await _fetchFallbackImage(match['contentId']!, serviceKey);
      }
      merged.add({
        ...camp,
        'contentId': match['contentId'],
        'firstImageUrl': imageUrl,
      });
    }
    return merged;
  }

  List<Map<String, dynamic>> _applySearchFilters(List<Map<String, dynamic>> camps) {
    return camps.where((camp) {
      if (_searchKeyword.isNotEmpty &&
          !camp['name'].toString().toLowerCase().contains(_searchKeyword.toLowerCase())) {
        return false;
      }
      if (_filterRegions.isNotEmpty) {
        final region = camp['location'].toString().split(' ').first;
        if (!_filterRegions.contains(region)) return false;
      }
      if (_filterTypes.isNotEmpty && !_filterTypes.contains(camp['type'])) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<Map<String, dynamic>?> fetchAvailability(String docId) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('realtime_availability').doc(docId).get();
      if (snap.exists) {
        final key = DateFormat('yyyy-MM-dd').format(selectedDateObj);
        if (snap.data()!.containsKey(key)) {
          return snap.data()![key] as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> _sortByAvailability(List<Map<String, dynamic>> camps) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDateObj);
    final list = <Map<String, dynamic>>[];
    for (var camp in camps) {
      final snap = await FirebaseFirestore.instance.collection('realtime_availability').doc(camp['name']).get();
      final a = (snap.exists && snap.data()!.containsKey(dateKey))
          ? (snap.data()![dateKey]!['available'] as int)
          : 0;
      camp['__isAvailable'] = a > 0;
      camp['available'] = a;
      camp['total'] = (snap.exists && snap.data()!.containsKey(dateKey))
          ? (snap.data()![dateKey]!['total'] as int)
          : 0;
      list.add(camp);
    }
    list.sort((a, b) {
      final ai = a['__isAvailable'] ? 1 : 0;
      final bi = b['__isAvailable'] ? 1 : 0;
      return bi - ai;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('M월 d일').format(selectedDateObj);
    final headerLabel = '$dateLabel 예약 현황';

    return Scaffold(
      appBar: AppBar(
        title: const Text('금오캠핑'),
        centerTitle: true,
        elevation: 0,
        // actions를 비워서 오른쪽 돋보기 버튼 제거
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _mergedDataFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('데이터 로드 오류: ${snap.error}'));
          }

          final merged = snap.data!;
          final filtered = _applySearchFilters(merged);

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _sortByAvailability(filtered),
            builder: (ctx2, snap2) {
              if (snap2.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap2.hasError) {
                return Center(child: Text('정렬 오류: ${snap2.error}'));
              }

              final camps = snap2.data!;
              return Column(
                children: [
                  // 검색창
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: () async {
                        final res = await Navigator.pushNamed(context, '/search');
                        if (res is Map<String, dynamic>) {
                          setState(() {
                            selectedDateObj = res['selectedDate'];
                            _searchKeyword = res['keyword'] ?? '';
                            _filterRegions = List<String>.from(res['selectedRegions'] ?? []);
                            _filterTypes = List<String>.from(res['selectedTypes'] ?? []);
                          });
                        }
                      },
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search, color: Colors.grey),
                            SizedBox(width: 8),
                            Text('검색하기', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 날짜 헤더
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        headerLabel,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 결과 영역
                  Expanded(
                    child: camps.isEmpty
                        ? const Center(child: Text('검색 결과가 없습니다.'))
                        : ListView.builder(
                      itemCount: camps.length,
                      itemBuilder: (c, i) {
                        final camp = camps[i];
                        final isAvail = camp['__isAvailable'] as bool;
                        final available = camp['available'] as int;
                        final total = camp['total'] as int;
                        return Opacity(
                          opacity: isAvail ? 1 : 0.4,
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  if (camp['firstImageUrl'] != null &&
                                      (camp['firstImageUrl'] as String).isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        camp['firstImageUrl'] as String,
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
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                camp['name'],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: Icon(
                                                widget.bookmarked[camp['name']] == true
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color: widget.bookmarked[camp['name']] == true
                                                    ? Colors.red
                                                    : Colors.grey,
                                              ),
                                              onPressed: () => widget.onToggleBookmark(camp['name']),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${camp['location']} | ${camp['type']}',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          isAvail
                                              ? '예약 가능 ($available/$total)'
                                              : '예약 마감 ($available/$total)',
                                          style: TextStyle(
                                            color: isAvail ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => CampingInfoScreen(camp: camp)),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isAvail ? Colors.green : Colors.grey,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('둘러보기'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
