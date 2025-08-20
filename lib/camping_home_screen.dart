// lib/screens/camping_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

import 'camping_info_screen.dart';
import 'prototype_screen.dart'; // 위치 테스트용(선택)
import 'package:shared_preferences/shared_preferences.dart';

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

  // ---- 내 위치 (기본값 + 저장 위치 로드) ---------------------------------
  double _userLat = 36.1190;
  double _userLng = 128.3446;
  String _currentPlaceName = '구미시';
  bool _onlyAvailable = false;

  void updateUserLocation(String name, double lat, double lng) {
    if (!mounted) return;
    setState(() {
      _currentPlaceName = name;
      _userLat = lat;
      _userLng = lng;
    });
  }

  Future<void> _loadHomeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('home');
    if (json != null) {
      final data = jsonDecode(json);
      if (!mounted) return;
      setState(() {
        _currentPlaceName = data['n'] ?? _currentPlaceName;
        _userLat = (data['lat'] as num?)?.toDouble() ?? _userLat;
        _userLng = (data['lng'] as num?)?.toDouble() ?? _userLng;
      });
    }
  }
  // ---------------------------------------------------------------------

  // ---- 필터 상태 --------------------------------------------------------
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
  // ---------------------------------------------------------------------

  List<Map<String, dynamic>> _camps = [];

  // ---- 날씨 캐시 (좌표+날짜별) ------------------------------------------
  static final Map<String, Map<String, dynamic>?> _weatherCache = {};
  // ---------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadHomeLocation();
    FirebaseFirestore.instance.collection('campgrounds').snapshots().listen((snap) {
      if (!mounted) return;
      setState(() {
        _camps = snap.docs.map((d) => d.data()! as Map<String, dynamic>).toList();
      });
    });
  }

  // ======================= 유틸(거리) ===================================
  double _deg2rad(double d) => d * (math.pi / 180);
  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
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
  // =====================================================================

  // ======================= Open-Meteo (하루 데이터) ======================
  Future<Map<String, dynamic>?> fetchWeatherForDate(
    double lat,
    double lng,
    DateTime date,
  ) async {
    DateTime just(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
    final d = just(date);
    final today = just(DateTime.now());
    final diffDays = d.difference(today).inDays;

    // 과거 또는 14일 범위 밖이면 숨김
    if (diffDays < 0 || diffDays > 13) return null;

    final dateStr = DateFormat('yyyy-MM-dd').format(d);
    final cacheKey = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}|$dateStr';
    if (_weatherCache.containsKey(cacheKey)) return _weatherCache[cacheKey];

    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${lat.toStringAsFixed(4)}'
      '&longitude=${lng.toStringAsFixed(4)}'
      '&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_mean'
      '&forecast_days=14'
      '&timezone=auto',
    );

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;

      final decoded = utf8.decode(resp.bodyBytes);
      final data = json.decode(decoded) as Map<String, dynamic>;
      final List times = (data['daily']?['time'] as List?) ?? [];
      final List codes = (data['daily']?['weathercode'] as List?) ?? [];
      final List tmax = (data['daily']?['temperature_2m_max'] as List?) ?? [];
      final List tmin = (data['daily']?['temperature_2m_min'] as List?) ?? [];
      final List prcpProb =
          (data['daily']?['precipitation_probability_mean'] as List?) ?? [];

      final idx = times.indexOf(dateStr);
      if (idx < 0) return null;

      final code = (codes[idx] as num?)?.toInt();
      final result = {
        'wmo': code,
        'text': _wmoKoText(code),
        'temp': _avgNum(tmax[idx], tmin[idx]),
        'max': (tmax[idx] as num?)?.toDouble(),
        'min': (tmin[idx] as num?)?.toDouble(),
        'chanceOfRain': (prcpProb.isNotEmpty && prcpProb[idx] != null)
            ? (prcpProb[idx] as num).round()
            : null,
      };

      _weatherCache[cacheKey] = result;
      return result;
    } catch (_) {
      return null;
    }
  }
  // =====================================================================

  // ======================= 필터 Drawer ==================================
  Widget _buildFilterDrawer(BuildContext context) {
    return Drawer(
      width: 320,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 고정 바
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  const Text('검색 필터',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.teal),
                    tooltip: '초기화',
                    onPressed: () {
                      setState(() {
                        _filterKeyword = null;
                        _filterRegion.clear();
                        _filterType.clear();
                        _filterDuty.clear();
                        _filterEnv.clear();
                        _filterAmenity.clear();
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.teal),
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
            // 옵션들 스크롤
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
                      options: _camps
                          .map((c) => (c['location'] as String).split(' ').first)
                          .toSet()
                          .toList()
                        ..sort(),
                      selected: _filterRegion,
                      onToggle: (opt) => setState(() {
                        _filterRegion.contains(opt)
                            ? _filterRegion.remove(opt)
                            : _filterRegion.add(opt);
                      }),
                    ),
                    _buildSection(
                      title: '캠핑장 유형',
                      options: _camps.map((c) => c['type'] as String).toSet().toList()
                        ..sort(),
                      selected: _filterType,
                      onToggle: (opt) => setState(() {
                        _filterType.contains(opt)
                            ? _filterType.remove(opt)
                            : _filterType.add(opt);
                      }),
                    ),
                    _buildSection(
                      title: '야영장 구분',
                      options: _camps
                          .map((c) => (c['inDuty'] as String? ?? '').split(','))
                          .expand((e) => e)
                          .where((s) => s.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(),
                      selected: _filterDuty,
                      onToggle: (opt) => setState(() {
                        _filterDuty.contains(opt)
                            ? _filterDuty.remove(opt)
                            : _filterDuty.add(opt);
                      }),
                    ),
                    _buildSection(
                      title: '환경',
                      options: _camps
                          .map((c) => c['lctCl'] as String? ?? '')
                          .where((e) => e.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(),
                      selected: _filterEnv,
                      onToggle: (opt) => setState(() {
                        _filterEnv.contains(opt)
                            ? _filterEnv.remove(opt)
                            : _filterEnv.add(opt);
                      }),
                    ),
                    _buildSection(
                      title: '편의시설',
                      options: _camps
                          .expand((c) => (c['amenities'] as List<dynamic>? ?? []).cast<String>())
                          .toSet()
                          .toList()
                        ..sort(),
                      selected: _filterAmenity,
                      onToggle: (opt) => setState(() {
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
          children: options
              .map((opt) => ChoiceChip(
                    label: Text(opt),
                    selected: selected.contains(opt),
                    onSelected: (_) => onToggle(opt),
                    selectedColor: Colors.teal.shade100,
                    backgroundColor: Colors.grey.shade200,
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
  // =====================================================================

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 13)),
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
          // (선택) 위치 프로토타입 화면 버튼
          IconButton(
            icon: const Icon(Icons.developer_mode),
            tooltip: '프로토타입 테스트',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrototypeScreen(
                    onLocationChange: updateUserLocation,
                  ),
                ),
              );
            },
          ),
          // 필터 버튼
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
          // 검색 + 날짜
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
                    child: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),

          // 실시간 데이터(캠핑장 + 예약현황)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('campgrounds').snapshots(),
              builder: (ctx, campSnap) {
                if (!campSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final camps = campSnap.data!.docs
                    .map((d) => d.data()! as Map<String, dynamic>)
                    .toList();

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('realtime_availability')
                      .snapshots(),
                  builder: (ctx2, availSnap) {
                    if (!availSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // id: 캠핑장 이름으로 문서가 있다고 가정
                    final availabilityMap = <String, Map<String, dynamic>>{};
                    for (var doc in availSnap.data!.docs) {
                      availabilityMap[doc.id] = doc.data()! as Map<String, dynamic>;
                    }

                    // 필터링
                    final filtered = camps.where((c) {
                      final name = (c['name'] as String).toLowerCase();
                      if (_appliedKeyword != null &&
                          _appliedKeyword!.isNotEmpty &&
                          !name.contains(_appliedKeyword!.toLowerCase())) {
                        return false;
                      }
                      final region = (c['location'] as String).split(' ').first;
                      if (_appliedRegion.isNotEmpty && !_appliedRegion.contains(region)) {
                        return false;
                      }
                      if (_appliedType.isNotEmpty &&
                          !_appliedType.contains(c['type'] as String)) {
                        return false;
                      }
                      final duties = (c['inDuty'] as String? ?? '').split(',');
                      if (_appliedDuty.isNotEmpty &&
                          !_appliedDuty.any((d) => duties.contains(d))) {
                        return false;
                      }
                      final env = c['lctCl'] as String? ?? '';
                      if (_appliedEnv.isNotEmpty && !_appliedEnv.contains(env)) {
                        return false;
                      }
                      final amens = (c['amenities'] as List<dynamic>? ?? []).cast<String>();
                      if (_appliedAmenity.isNotEmpty &&
                          !_appliedAmenity.every(amens.contains)) {
                        return false;
                      }
                      if (_onlyAvailable) {
                        final avail = (availabilityMap[c['name']]?[dateKey]?['available'] ??
                                c['available']) as int? ??
                            0;
                        if (avail <= 0) return false;
                      }
                      return true;
                    }).toList();

                    // 거리순 정렬
                    filtered.sort((a, b) => _campDistance(a).compareTo(_campDistance(b)));

                    final count = filtered.length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 개수 + 현위치 + "예약가능만" 토글
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('$count개의 캠핑장이 검색되었어요!'),
                                  const SizedBox(width: 12),
                                  if (_currentPlaceName.isNotEmpty)
                                    Text(
                                      '현위치 : $_currentPlaceName',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('예약 가능한 캠핑장만 출력',
                                    style: TextStyle(fontSize: 14)),
                                value: _onlyAvailable,
                                onChanged: (val) {
                                  if (val != null) setState(() => _onlyAvailable = val);
                                },
                                controlAffinity: ListTileControlAffinity.trailing,
                              ),
                            ],
                          ),
                        ),

                        // 결과 리스트
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                                  child: Text(
                                    '검색결과가 없습니다',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  itemCount: filtered.length,
                                  itemBuilder: (ctx4, i) {
                                    final c = filtered[i];
                                    final aMap = availabilityMap[c['name']]?[dateKey]
                                        as Map<String, dynamic>?;
                                    final avail = aMap?['available'] as int? ??
                                        (c['available'] as int? ?? 0);
                                    final total = aMap?['total'] as int? ??
                                        (c['total'] as int? ?? 0);
                                    final isAvail = avail > 0;

                                    final lat =
                                        double.tryParse(c['mapY']?.toString() ?? '') ?? 0.0;
                                    final lng =
                                        double.tryParse(c['mapX']?.toString() ?? '') ?? 0.0;
                                    final distance =
                                        _campDistance(c).isFinite
                                            ? _campDistance(c).toStringAsFixed(1)
                                            : '-';

                                    return FutureBuilder<Map<String, dynamic>?>(
                                      future: fetchWeatherForDate(
                                          lat, lng, widget.selectedDate),
                                      builder: (context, snapshot) {
                                        final weather = snapshot.data;

                                        return Opacity(
                                          opacity: isAvail ? 1 : 0.4,
                                          child: InkWell(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => CampingInfoScreen(
                                                  campName: c['name'],
                                                  available: avail,
                                                  total: total,
                                                  isBookmarked:
                                                      widget.bookmarked[c['name']] == true,
                                                  onToggleBookmark: widget.onToggleBookmark,
                                                  selectedDate: widget.selectedDate,
                                                ),
                                              ),
                                            ),
                                            child: Card(
                                              margin: const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Row(
                                                  children: [
                                                    if (c['firstImageUrl'] != null &&
                                                        (c['firstImageUrl'] as String).isNotEmpty)
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        child: Image.network(
                                                          c['firstImageUrl'],
                                                          width: 60,
                                                          height: 60,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      )
                                                    else
                                                      const Icon(Icons.park,
                                                          size: 48, color: Colors.teal),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            c['name'],
                                                            style: const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            '${c['location']} | ${c['type']}',
                                                            style: const TextStyle(
                                                                fontSize: 12,
                                                                color: Colors.grey),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Row(
                                                            children: [
                                                              Text(
                                                                '거리: $distance km',
                                                                style: const TextStyle(
                                                                    fontSize: 12,
                                                                    color: Colors.grey),
                                                              ),
                                                              const Spacer(),
                                                              if (weather != null) ...[
                                                                Icon(
                                                                  _wmoIcon(weather['wmo'] as int?),
                                                                  size: 18,
                                                                ),
                                                                const SizedBox(width: 4),
                                                                Text(
                                                                  '${(weather['temp'] as double?)?.toStringAsFixed(1) ?? '-'}℃'
                                                                  '${weather['chanceOfRain'] != null ? ' · 강수확률 ${weather['chanceOfRain']}%' : ''}',
                                                                  style: const TextStyle(fontSize: 12),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Text(
                                                            isAvail
                                                                ? '예약 가능 ($avail/$total)'
                                                                : '예약 마감 ($avail/$total)',
                                                            style: TextStyle(
                                                              color: isAvail
                                                                  ? Colors.green
                                                                  : Colors.red,
                                                              fontWeight: FontWeight.bold,
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
                                                            : Icons.bookmark_border,
                                                        color:
                                                            (widget.bookmarked[c['name']] ??
                                                                    false)
                                                                ? Colors.red
                                                                : Colors.grey,
                                                      ),
                                                      onPressed: () =>
                                                          widget.onToggleBookmark(c['name']),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
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

// ======================= 헬퍼 (날씨 텍스트/아이콘/평균) ====================
double? _avgNum(dynamic a, dynamic b) {
  if (a == null || b == null) return null;
  return ((a as num).toDouble() + (b as num).toDouble()) / 2.0;
}

String _wmoKoText(int? code) {
  switch (code) {
    case 0:
      return '맑음';
    case 1:
    case 2:
      return '부분적 흐림';
    case 3:
      return '흐림';
    case 45:
    case 48:
      return '안개';
    case 51:
    case 53:
    case 55:
      return '이슬비';
    case 61:
    case 63:
    case 65:
      return '비';
    case 71:
    case 73:
    case 75:
      return '눈';
    case 80:
    case 81:
    case 82:
      return '소나기';
    case 95:
      return '천둥번개';
    default:
      return '날씨';
  }
}

IconData _wmoIcon(int? code) {
  if (code == null) return Icons.wb_cloudy;
  if (code == 0) return Icons.wb_sunny;
  if ([1, 2].contains(code)) return Icons.cloud_queue;
  if (code == 3) return Icons.cloud;
  if ([61, 63, 65, 80, 81, 82].contains(code)) return Icons.water_drop;
  if ([71, 73, 75].contains(code)) return Icons.ac_unit;
  if ([95].contains(code)) return Icons.thunderstorm;
  return Icons.wb_cloudy;
}
