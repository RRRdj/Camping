// lib/screens/camping_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

import 'camping_info_screen.dart';
import 'place_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 별점 정렬 옵션
enum RatingSort { none, highFirst, lowFirst }

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

// ────────────────────────── 필터 섹션 공통 위젯 ──────────────────────────
class _FilterSection extends StatelessWidget {
  final String title;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;

  const _FilterSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = selected.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              if (count > 0)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              const Spacer(),
              if (count > 0)
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('전체 해제'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSel = selected.contains(opt);
              return ChoiceChip(
                label: Text(opt, overflow: TextOverflow.ellipsis),
                selected: isSel,
                onSelected: (_) => onToggle(opt),
                labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                showCheckmark: false,
                shape: const StadiumBorder(),
                side: BorderSide(color: cs.outlineVariant),
                selectedColor: cs.primaryContainer,
                backgroundColor: cs.surface,
                labelStyle: TextStyle(
                  color: isSel ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
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
    final jsonStr = prefs.getString('home');
    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _currentPlaceName = (data['n'] as String?) ?? _currentPlaceName;
          _userLat = (data['lat'] as num?)?.toDouble() ?? _userLat;
          _userLng = (data['lng'] as num?)?.toDouble() ?? _userLng;
        });
      } catch (_) {}
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

  // 별점 정렬 상태
  RatingSort _ratingSort = RatingSort.none;
  // ---------------------------------------------------------------------

  List<Map<String, dynamic>> _camps = [];

  // ---- 날씨 캐시 (좌표+날짜별) ------------------------------------------
  static final Map<String, Map<String, dynamic>?> _weatherCache = {};

  // ---- 평균 별점 캐시 (contentId -> avg) -------------------------------
  final Map<String, double?> _avgRatingCache = {};
  // ---------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadHomeLocation();
    FirebaseFirestore.instance
        .collection('campgrounds')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _camps =
            snap.docs.map((d) => d.data()! as Map<String, dynamic>).toList();
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

    if (diffDays < 0 || diffDays > 13) return null;

    final dateStr = DateFormat('yyyy-MM-dd').format(d);
    final cacheKey =
        '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}|$dateStr';
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

  // ======================= 평균 별점 로더 (캐시 활용) ====================
  Future<Map<String, double?>> _loadAvgRatingsFor(
      List<Map<String, dynamic>> camps,
      ) async {
    final Map<String, double?> result = {};
    final ids = <String>[];

    for (final c in camps) {
      final id = c['contentId']?.toString() ?? '';
      if (id.isEmpty) {
        result[id] = null;
        continue;
      }
      if (_avgRatingCache.containsKey(id)) {
        result[id] = _avgRatingCache[id];
      } else {
        ids.add(id);
      }
    }
    if (ids.isEmpty) return result;

    const chunkSize = 10;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, math.min(i + chunkSize, ids.length));
      await Future.wait(
        chunk.map((id) async {
          final snap = await FirebaseFirestore.instance
              .collection('campground_reviews')
              .doc(id)
              .collection('reviews')
              .get();

          if (snap.docs.isEmpty) {
            _avgRatingCache[id] = null;
            result[id] = null;
            return;
          }
          double sum = 0;
          var cnt = 0;
          for (final d in snap.docs) {
            final r = d.data()['rating'];
            if (r is num) {
              sum += r.toDouble();
              cnt++;
            }
          }
          final avg = cnt == 0 ? null : (sum / cnt);
          _avgRatingCache[id] = avg;
          result[id] = avg;
        }),
      );
    }

    return result;
  }
  // =====================================================================

  // ======================= 필터 Drawer ==================================
  Widget _buildFilterDrawer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Drawer(
      width: 340,
      child: SafeArea(
        child: Column(
          children: [
            // 상단 고정 헤더
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  Text(
                    '검색 필터',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    tooltip: '닫기',
                  ),
                ],
              ),
            ),

            // 본문 (스크롤)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilterSection(
                      title: '지역',
                      options: _camps
                          .map((c) =>
                      (c['location'] as String).split(' ').first)
                          .toSet()
                          .toList()
                        ..sort(),
                      selected: _filterRegion,
                      onToggle: (opt) {
                        setState(() {
                          _filterRegion.contains(opt)
                              ? _filterRegion.remove(opt)
                              : _filterRegion.add(opt);
                        });
                      },
                      onClear: () => setState(() => _filterRegion.clear()),
                    ),
                    _FilterSection(
                      title: '캠핑장 유형',
                      options: _camps
                          .map((c) => c['type'] as String)
                          .toSet()
                          .toList()
                        ..sort(),
                      selected: _filterType,
                      onToggle: (opt) {
                        setState(() {
                          _filterType.contains(opt)
                              ? _filterType.remove(opt)
                              : _filterType.add(opt);
                        });
                      },
                      onClear: () => setState(() => _filterType.clear()),
                    ),
                    _FilterSection(
                      title: '야영장 구분',
                      options: _camps
                          .map((c) => (c['inDuty'] as String? ?? '').split(','))
                          .expand((e) => e)
                          .where((s) => s.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(),
                      selected: _filterDuty,
                      onToggle: (opt) {
                        setState(() {
                          _filterDuty.contains(opt)
                              ? _filterDuty.remove(opt)
                              : _filterDuty.add(opt);
                        });
                      },
                      onClear: () => setState(() => _filterDuty.clear()),
                    ),
                    _FilterSection(
                      title: '환경',
                      options: _camps
                          .map((c) => c['lctCl'] as String? ?? '')
                          .where((e) => e.isNotEmpty)
                          .toSet()
                          .toList()
                        ..sort(),
                      selected: _filterEnv,
                      onToggle: (opt) {
                        setState(() {
                          _filterEnv.contains(opt)
                              ? _filterEnv.remove(opt)
                              : _filterEnv.add(opt);
                        });
                      },
                      onClear: () => setState(() => _filterEnv.clear()),
                    ),
                    _FilterSection(
                      title: '편의시설',
                      options: _camps
                          .expand((c) =>
                          (c['amenities'] as List<dynamic>? ?? [])
                              .cast<String>())
                          .toSet()
                          .toList()
                        ..sort(),
                      selected: _filterAmenity,
                      onToggle: (opt) {
                        setState(() {
                          _filterAmenity.contains(opt)
                              ? _filterAmenity.remove(opt)
                              : _filterAmenity.add(opt);
                        });
                      },
                      onClear: () => setState(() => _filterAmenity.clear()),
                    ),
                  ],
                ),
              ),
            ),

            // 하단 고정 버튼
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).padding.bottom + 8,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('초기화'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.onSurface,
                        side: BorderSide(color: cs.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('적용'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildFilterDrawer(context),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: cs.surfaceContainerHigh,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '[ $dateLabel 캠핑장 현황 ]',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
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
          // 상단 검색 + 날짜 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '검색어를 입력하세요',
                      hintStyle:
                      TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 정렬 + 예약가능 스위치 (컨트롤 바)
          ControlBar(
            ratingSort: _ratingSort,
            onChangeSort: (v) => setState(() => _ratingSort = v),
            onlyAvailable: _onlyAvailable,
            onToggleOnly: (v) => setState(() => _onlyAvailable = v),
          ),

          // 실시간 데이터(캠핑장 + 예약현황)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('campgrounds')
                  .snapshots(),
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

                    final availabilityMap = <String, Map<String, dynamic>>{};
                    for (var doc in availSnap.data!.docs) {
                      availabilityMap[doc.id] =
                      doc.data()! as Map<String, dynamic>;
                    }

                    // 필터링
                    final filtered = camps.where((c) {
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
                      final duties =
                      (c['inDuty'] as String? ?? '').split(',');
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
                      if (_onlyAvailable) {
                        final avail =
                            (availabilityMap[c['name']]?[dateKey]?['available'] ??
                                c['available']) as int? ??
                                0;
                        if (avail <= 0) return false;
                      }
                      return true;
                    }).toList();

                    // 거리순 정렬
                    filtered.sort((a, b) =>
                        _campDistance(a).compareTo(_campDistance(b)));

                    // 정렬 안정성 위해 baseIdx 부여
                    final baseItems = List.generate(filtered.length, (i) {
                      return {'camp': filtered[i], 'baseIdx': i};
                    });

                    final count = filtered.length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 개수 + 현위치(변경) — Wrap으로 변경하여 줄바꿈 & 칩 확장 허용
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('$count개의 캠핑장이 검색되었어요!'),
                              _LocationChip(
                                placeName: _currentPlaceName,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlaceSearchScreen(
                                        onLocationChange: updateUserLocation,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // 결과 리스트
                        Expanded(
                          child: (_ratingSort == RatingSort.none)
                              ? _buildListView(
                              baseItems, availabilityMap, dateKey)
                              : FutureBuilder<Map<String, double?>>(
                            future: _loadAvgRatingsFor(
                              baseItems
                                  .take(10)
                                  .map((e) => e['camp']
                              as Map<String, dynamic>)
                                  .toList(),
                            ),
                            builder: (context, ratingSnap) {
                              if (!ratingSnap.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              final ratingMap = ratingSnap.data!;
                              final sorted =
                              List<Map<String, dynamic>>.from(
                                  baseItems);

                              int cmp(Map<String, dynamic> a,
                                  Map<String, dynamic> b) {
                                final ca = a['camp']
                                as Map<String, dynamic>;
                                final cb = b['camp']
                                as Map<String, dynamic>;
                                final ida =
                                    ca['contentId']?.toString() ?? '';
                                final idb =
                                    cb['contentId']?.toString() ?? '';
                                final ra = ratingMap[ida];
                                final rb = ratingMap[idb];

                                final hasA = ra != null;
                                final hasB = rb != null;

                                if (hasA && hasB) {
                                  final diff = (ra! - rb!).toDouble();
                                  if (_ratingSort ==
                                      RatingSort.highFirst) {
                                    if (diff.abs() > 1e-9) {
                                      return -diff.sign.toInt();
                                    }
                                  } else {
                                    if (diff.abs() > 1e-9) {
                                      return diff.sign.toInt();
                                    }
                                  }
                                  return (a['baseIdx'] as int)
                                      .compareTo(b['baseIdx'] as int);
                                } else if (hasA && !hasB) {
                                  return -1;
                                } else if (!hasA && hasB) {
                                  return 1;
                                } else {
                                  return (a['baseIdx'] as int)
                                      .compareTo(b['baseIdx'] as int);
                                }
                              }

                              sorted.sort(cmp);
                              return _buildListView(sorted,
                                  availabilityMap, dateKey);
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

  // 리스트 빌더 (공통) — CampCard 사용
  Widget _buildListView(
      List<Map<String, dynamic>> items,
      Map<String, Map<String, dynamic>> availabilityMap,
      String dateKey,
      ) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          '검색결과가 없습니다',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      cacheExtent: 800,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: items.length,
      itemBuilder: (ctx4, i) {
        final c = items[i]['camp'] as Map<String, dynamic>;
        final aMap =
        availabilityMap[c['name']]?[dateKey] as Map<String, dynamic>?;
        final avail =
            aMap?['available'] as int? ?? (c['available'] as int? ?? 0);
        final total = aMap?['total'] as int? ?? (c['total'] as int? ?? 0);
        final isAvail = avail > 0;

        final lat = double.tryParse(c['mapY']?.toString() ?? '') ?? 0.0;
        final lng = double.tryParse(c['mapX']?.toString() ?? '') ?? 0.0;
        final dist = _campDistance(c);
        final distance = dist.isFinite ? dist.toStringAsFixed(1) : '-';

        return FutureBuilder<Map<String, dynamic>?>(
          future: fetchWeatherForDate(lat, lng, widget.selectedDate),
          builder: (context, snapshot) {
            final weather = snapshot.data;

            return CampCard(
              camp: c,
              distanceKm: distance,
              isAvailable: isAvail,
              avail: avail,
              total: total,
              weather: weather,
              bookmarked: (widget.bookmarked[c['name']] ?? false),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CampingInfoScreen(
                    campName: c['name'],
                    available: avail,
                    total: total,
                    isBookmarked: widget.bookmarked[c['name']] == true,
                    onToggleBookmark: widget.onToggleBookmark,
                    selectedDate: widget.selectedDate,
                  ),
                ),
              ),
              onToggleBookmark: () => widget.onToggleBookmark(c['name']),
            );
          },
        );
      },
    );
  }
}

// ───────────────────────── 상단 컨트롤 바 ─────────────────────────
class ControlBar extends StatelessWidget {
  final RatingSort ratingSort;
  final ValueChanged<RatingSort> onChangeSort;
  final bool onlyAvailable;
  final ValueChanged<bool> onToggleOnly;

  const ControlBar({
    super.key,
    required this.ratingSort,
    required this.onChangeSort,
    required this.onlyAvailable,
    required this.onToggleOnly,
  });

  @override
  Widget build(BuildContext context) {
    Widget _segLabel(IconData icon, String text, {double gap = 4}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          if (gap > 0) SizedBox(width: gap),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<RatingSort>(
              segments: [
                ButtonSegment(
                  value: RatingSort.none,
                  label: _segLabel(Icons.filter_list_rounded, '거리순', gap: 2),
                ),
                ButtonSegment(
                  value: RatingSort.highFirst,
                  label: _segLabel(Icons.star, '높은순', gap: 2),
                ),
                ButtonSegment(
                  value: RatingSort.lowFirst,
                  label: _segLabel(Icons.star_border, '낮은순', gap: 2),
                ),
              ],
              selected: {ratingSort},
              onSelectionChanged: (s) => onChangeSort(s.first),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                selectedBackgroundColor: Colors.teal.withOpacity(0.12),
                selectedForegroundColor: Colors.teal.shade800,
                backgroundColor: Theme.of(context).colorScheme.surface,
                side: BorderSide(color: Theme.of(context).dividerColor),
                shape: const StadiumBorder(),
              ),
            ),
          ),
          const SizedBox(width: 24),
          const Text(
            '예약 가능',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Switch(
            value: onlyAvailable,
            onChanged: onToggleOnly,
            activeColor: Colors.teal,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 장소 설정 칩(멀티라인) ────────────────────────
class _LocationChip extends StatelessWidget {
  final String placeName;
  final VoidCallback onTap;
  const _LocationChip({required this.placeName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxW = MediaQuery.of(context).size.width - 32;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.place_outlined, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),

              // ⬇️ Flexible → Expanded 로 변경 (여러 줄 허용은 그대로)
              Expanded(
                child: Text(
                  placeName,
                  softWrap: true,
                  style: TextStyle(fontSize: 12, color: cs.onSurface),
                ),
              ),

              const SizedBox(width: 8),
              // 오른쪽 끝에 고정될 트레일 영역
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 1, height: 14, color: cs.outlineVariant),
                  const SizedBox(width: 8),
                  Text(
                    '변경',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ───────────────────────── 캠프 카드(공통 아이템) ────────────────────────
class CampCard extends StatelessWidget {
  final Map<String, dynamic> camp;
  final String distanceKm;
  final bool isAvailable;
  final int avail;
  final int total;
  final Map<String, dynamic>? weather; // { wmo, temp(double), chanceOfRain(int) }
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback onToggleBookmark;

  const CampCard({
    super.key,
    required this.camp,
    required this.distanceKm,
    required this.isAvailable,
    required this.avail,
    required this.total,
    required this.weather,
    required this.bookmarked,
    required this.onTap,
    required this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final wmo = (weather?['wmo'] as num?)?.toInt();
    final temp = (weather?['temp'] as num?)?.toDouble();
    final rain = weather?['chanceOfRain'] as int?;
    final availColor =
    isAvailable ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final availBg =
    isAvailable ? const Color(0xFFE9F7EE) : const Color(0xFFFDECEC);

    final contentId = camp['contentId']?.toString() ?? '';

    return AnimatedOpacity(
      opacity: isAvailable ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 썸네일
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: (camp['firstImageUrl'] != null &&
                      (camp['firstImageUrl'] as String).isNotEmpty)
                      ? Image.network(
                    camp['firstImageUrl'],
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                  )
                      : Container(
                    width: 76,
                    height: 76,
                    color: const Color(0xFFF0F2F5),
                    child: const Icon(Icons.park,
                        color: Colors.teal, size: 34),
                  ),
                ),
                const SizedBox(width: 12),

                // 오른쪽 정보 영역
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1행: 이름 + 별점
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              camp['name'] ?? '',
                              softWrap: true, // 말줄임 없이 여러 줄 허용
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (contentId.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _LiveAverageRatingBadge(
                                contentId: contentId, dense: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 2행: 주소 · 유형  |  거리 + 북마크 (같은 라인)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_formatAddress(camp)} · ${camp['type'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${distanceKm}km',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(width: 2),
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                bookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                size: 20,
                                color: bookmarked ? Colors.red : Colors.grey,
                              ),
                              onPressed: onToggleBookmark,
                              tooltip: '북마크',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 3행: (좌) 날씨  ────  (우) 가능/마감 Pill
                      Row(
                        children: [
                          if (weather != null)
                            _WeatherPill(wmo: wmo, temp: temp, rain: rain),
                          const Spacer(),
                          _AvailPill(
                            isAvailable: isAvailable,
                            avail: avail,
                            total: total,
                            color: availColor,
                            bg: availBg,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── 보조(날씨/가능Pill) ─────────────────────────
class _WeatherPill extends StatelessWidget {
  final int? wmo;
  final double? temp;
  final int? rain;
  const _WeatherPill({this.wmo, this.temp, this.rain});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text =
        '${temp?.toStringAsFixed(1) ?? '-'}℃${rain != null ? ' · ${rain}%' : ''}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_wmoIcon(wmo), size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailPill extends StatelessWidget {
  final bool isAvailable;
  final int avail;
  final int total;
  final Color color;
  final Color bg;
  const _AvailPill({
    required this.isAvailable,
    required this.avail,
    required this.total,
    required this.color,
    required this.bg,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isAvailable ? '예약 가능 $avail/$total' : '예약 마감 $avail/$total',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ───────────────────────── ⭐ 평균 별점 배지(실시간) ──────────────────────
class _LiveAverageRatingBadge extends StatelessWidget {
  final String contentId;
  final bool dense;

  const _LiveAverageRatingBadge({required this.contentId, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();

        double sum = 0;
        int cnt = 0;
        for (final d in docs) {
          final m = d.data() as Map<String, dynamic>;
          final r = m['rating'];
          if (r is num) {
            sum += r.toDouble();
            cnt++;
          }
        }
        if (cnt == 0) return const SizedBox.shrink();

        final avg = sum / cnt;
        final avgText = avg.toStringAsFixed(1);

        final padH = dense ? 6.0 : 8.0;
        final padV = dense ? 2.0 : 4.0;
        final fontSize = dense ? 12.0 : 13.0;
        final iconSize = dense ? 14.0 : 16.0;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.amber.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star, size: iconSize, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                avgText,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────── 주소 포맷 & 헬퍼 ─────────────────────────────
String _formatAddress(Map<String, dynamic> c) {
  final loc = (c['location'] as String?)?.trim();
  if (loc != null && loc.isNotEmpty) return loc;

  final doNm = (c['doNm'] as String?)?.trim() ?? '';
  final si = (c['sigunguNm'] as String?)?.trim() ?? '';
  final combo = [doNm, si].where((e) => e.isNotEmpty).join(' ');
  if (combo.isNotEmpty) return combo;

  return (c['addr1'] as String?)?.trim() ?? '';
}

double? _avgNum(dynamic a, dynamic b) {
  if (a == null || b == null) return null;
  return ((a as num).toDouble() + (b as num).toDouble()) / 2.0;
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
