import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math; // 거리 계산용
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // -- 내 위치(임시 하드코딩) -----------------------
  static const _userLat = 36.1190;
  static const _userLng = 128.3446;

  double _deg2rad(double d) => d * (math.pi / 180);
  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _campDistance(Map<String, dynamic> camp) {
    final lat = double.tryParse(camp['mapY']?.toString() ?? '');
    final lon = double.tryParse(camp['mapX']?.toString() ?? '');
    if (lat == null || lon == null) return double.infinity;
    return _distanceKm(_userLat, _userLng, lat, lon);
  }
  // ------------------------------------------------

  // 검색·필터 상태
  String? _appliedKeyword;
  List<String> _appliedRegion = [];
  List<String> _appliedType = [];
  List<String> _appliedDuty = [];
  List<String> _appliedEnv = [];
  List<String> _appliedAmenity = [];

  String? _filterKeyword;
  List<String> _filterRegion = [];
  List<String> _filterType = [];
  List<String> _filterDuty = [];
  List<String> _filterEnv = [];
  List<String> _filterAmenity = [];

  List<Map<String, dynamic>> _camps = [];

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.collection('campgrounds').snapshots().listen((
      snap,
    ) {
      setState(() {
        _camps =
            snap.docs.map((d) => d.data()! as Map<String, dynamic>).toList();
      });
    });
  }

  Widget _buildFilterDrawer(BuildContext context) {
    // Drawer with fixed header and scrollable content
    return Drawer(
      width: 320,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1) 고정된 상단바
            Container(
              height: 56,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  // 왼쪽 타이틀
                  Text(
                    '검색 필터',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  // 오른쪽 초기화 아이콘
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.teal),
                    tooltip: '초기화',
                    onPressed:
                        () => setState(() {
                          _filterKeyword = null;
                          _filterRegion.clear();
                          _filterType.clear();
                          _filterDuty.clear();
                          _filterEnv.clear();
                          _filterAmenity.clear();
                        }),
                  ),
                  // 오른쪽 적용 아이콘
                  IconButton(
                    icon: Icon(Icons.check, color: Colors.teal),
                    tooltip: '적용',
                    onPressed: () {
                      setState(() {
                        _appliedKeyword = _filterKeyword;
                        _appliedRegion = List.from(_filterRegion);
                        _appliedType = List.from(_filterType);
                        _appliedDuty = List.from(_filterDuty);
                        _appliedEnv = List.from(_filterEnv);
                        _appliedAmenity = List.from(_filterAmenity);
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // 2) 필터 섹션(스크롤 가능)
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      title: '지역',
                      options:
                          _camps
                              .map(
                                (c) =>
                                    (c['location'] as String).split(' ').first,
                              )
                              .toSet()
                              .toList()
                            ..sort(),
                      selected: _filterRegion,
                      onToggle:
                          (opt) => setState(() {
                            _filterRegion.contains(opt)
                                ? _filterRegion.remove(opt)
                                : _filterRegion.add(opt);
                          }),
                    ),
                    _buildSection(
                      title: '캠핑장 유형',
                      options:
                          _camps
                              .map((c) => c['type'] as String)
                              .toSet()
                              .toList()
                            ..sort(),
                      selected: _filterType,
                      onToggle:
                          (opt) => setState(() {
                            _filterType.contains(opt)
                                ? _filterType.remove(opt)
                                : _filterType.add(opt);
                          }),
                    ),
                    _buildSection(
                      title: '야영장 구분',
                      options:
                          _camps
                              .map(
                                (c) =>
                                    (c['inDuty'] as String? ?? '').split(','),
                              )
                              .expand((e) => e)
                              .where((s) => s.isNotEmpty)
                              .toSet()
                              .toList()
                            ..sort(),
                      selected: _filterDuty,
                      onToggle:
                          (opt) => setState(() {
                            _filterDuty.contains(opt)
                                ? _filterDuty.remove(opt)
                                : _filterDuty.add(opt);
                          }),
                    ),
                    _buildSection(
                      title: '환경',
                      options:
                          _camps
                              .map((c) => c['lctCl'] as String? ?? '')
                              .where((e) => e.isNotEmpty)
                              .toSet()
                              .toList()
                            ..sort(),
                      selected: _filterEnv,
                      onToggle:
                          (opt) => setState(() {
                            _filterEnv.contains(opt)
                                ? _filterEnv.remove(opt)
                                : _filterEnv.add(opt);
                          }),
                    ),
                    _buildSection(
                      title: '편의시설',
                      options:
                          _camps
                              .expand(
                                (c) =>
                                    (c['amenities'] as List<dynamic>? ?? [])
                                        .cast<String>(),
                              )
                              .toSet()
                              .toList()
                            ..sort(),
                      selected: _filterAmenity,
                      onToggle:
                          (opt) => setState(() {
                            _filterAmenity.contains(opt)
                                ? _filterAmenity.remove(opt)
                                : _filterAmenity.add(opt);
                          }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<String> options,
    required List<String> selected,
    required void Function(String) onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              options
                  .map(
                    (opt) => ChoiceChip(
                      label: Text(opt),
                      selected: selected.contains(opt),
                      onSelected: (_) => onToggle(opt),
                      selectedColor: Colors.teal.shade100,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
    );
    if (picked != null) widget.onDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('MM월 dd일').format(widget.selectedDate);
    final dateKey = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildFilterDrawer(context),
      appBar: AppBar(
        title: Text('[ $dateLabel 캠핑장 현황 ]'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              setState(() {
                _filterKeyword = _appliedKeyword;
                _filterRegion = List.from(_appliedRegion);
                _filterType = List.from(_appliedType);
                _filterDuty = List.from(_appliedDuty);
                _filterEnv = List.from(_appliedEnv);
                _filterAmenity = List.from(_appliedAmenity);
              });
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1) 검색창
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '검색어를 입력하세요',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _appliedKeyword = v),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2) 실시간 데이터 + 개수 표시
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('campgrounds')
                      .snapshots(),
              builder: (ctx, campSnap) {
                if (!campSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final camps =
                    campSnap.data!.docs
                        .map((d) => d.data()! as Map<String, dynamic>)
                        .toList();

                return StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('realtime_availability')
                          .snapshots(),
                  builder: (ctx2, availSnap) {
                    if (!availSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final availabilityMap = <String, Map<String, dynamic>>{};
                    for (var doc in availSnap.data!.docs) {
                      availabilityMap[doc.id] =
                          doc.data()! as Map<String, dynamic>;
                    }

                    // 필터링
                    final filtered =
                        camps.where((c) {
                          final name = (c['name'] as String).toLowerCase();
                          if (_appliedKeyword != null &&
                              _appliedKeyword!.isNotEmpty &&
                              !name.contains(_appliedKeyword!.toLowerCase())) {
                            return false;
                          }
                          final region =
                              (c['location'] as String).split(' ').first;
                          if (_appliedRegion.isNotEmpty &&
                              !_appliedRegion.contains(region)) {
                            return false;
                          }
                          if (_appliedType.isNotEmpty &&
                              !_appliedType.contains(c['type'] as String)) {
                            return false;
                          }
                          final duties = (c['inDuty'] as String? ?? '').split(
                            ',',
                          );
                          if (_appliedDuty.isNotEmpty &&
                              !_appliedDuty.any((d) => duties.contains(d))) {
                            return false;
                          }
                          final env = c['lctCl'] as String? ?? '';
                          if (_appliedEnv.isNotEmpty &&
                              !_appliedEnv.contains(env)) {
                            return false;
                          }
                          final amens =
                              (c['amenities'] as List<dynamic>? ?? [])
                                  .cast<String>();
                          if (_appliedAmenity.isNotEmpty &&
                              !_appliedAmenity.every(amens.contains)) {
                            return false;
                          }
                          return true;
                        }).toList();

                    // 정렬(거리순)
                    filtered.sort(
                      (a, b) => _campDistance(a).compareTo(_campDistance(b)),
                    );

                    //  검색된 개수
                    final count = filtered.length;

                    // 결과 UI: 상단에 개수, 하단에 리스트 혹은 ‘검색결과가 없습니다’
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ◀ 검색창 바로 아래에 카운트 표시
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            '$count개의 캠핑장이 검색되었어요!',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // 결과 목록 영역
                        Expanded(
                          child:
                              filtered.isEmpty
                                  ? const Center(
                                    child: Text(
                                      '검색결과가 없습니다',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                  : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    itemCount: filtered.length,
                                    itemBuilder: (ctx4, i) {
                                      final c = filtered[i];
                                      final aMap =
                                          availabilityMap[c['name']]?[dateKey]
                                              as Map<String, dynamic>?;
                                      final avail =
                                          aMap?['available'] as int? ??
                                          (c['available'] as int? ?? 0);
                                      final total =
                                          aMap?['total'] as int? ??
                                          (c['total'] as int? ?? 0);
                                      final isAvail = avail > 0;
                                      final distance = _campDistance(
                                        c,
                                      ).toStringAsFixed(1);

                                      return Opacity(
                                        opacity: isAvail ? 1 : 0.4,
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
                                                        isBookmarked:
                                                            widget
                                                                .bookmarked[c['name']] ==
                                                            true,
                                                        onToggleBookmark:
                                                            widget
                                                                .onToggleBookmark,
                                                        selectedDate:
                                                            widget.selectedDate,
                                                      ),
                                                ),
                                              ),
                                          child: Card(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Row(
                                                children: [
                                                  if (c['firstImageUrl'] !=
                                                          null &&
                                                      (c['firstImageUrl']
                                                              as String)
                                                          .isNotEmpty)
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      child: Image.network(
                                                        c['firstImageUrl'],
                                                        width: 60,
                                                        height: 60,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    )
                                                  else
                                                    const Icon(
                                                      Icons.park,
                                                      size: 48,
                                                      color: Colors.teal,
                                                    ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          c['name'],
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          '${c['location']} | ${c['type']}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          '거리: $distance km',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          isAvail
                                                              ? '예약 가능 ($avail/$total)'
                                                              : '예약 마감 ($avail/$total)',
                                                          style: TextStyle(
                                                            color:
                                                                isAvail
                                                                    ? Colors
                                                                        .green
                                                                    : Colors
                                                                        .red,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      (widget.bookmarked[c['name']] ??
                                                              false)
                                                          ? Icons.bookmark
                                                          : Icons
                                                              .bookmark_border,
                                                      color:
                                                          (widget.bookmarked[c['name']] ??
                                                                  false)
                                                              ? Colors.red
                                                              : Colors.grey,
                                                    ),
                                                    onPressed:
                                                        () => widget
                                                            .onToggleBookmark(
                                                              c['name'],
                                                            ),
                                                  ),
                                                ],
                                              ),
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
          ),
        ],
      ),
    );
  }
}
