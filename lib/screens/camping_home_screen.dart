import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

import 'camping_info_screen.dart';
import 'place_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _CampingHomeScreenState extends State<CampingHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  RatingSort _ratingSort = RatingSort.none;

  List<Map<String, dynamic>> _camps = [];

  static final Map<String, Map<String, dynamic>?> _weatherCache = {};

  final Map<String, double?> _avgRatingCache = {};

  @override
  void initState() {
    super.initState();
    _loadHomeLocation();
    FirebaseFirestore.instance.collection('campgrounds').snapshots().listen((
      snap,
    ) {
      if (!mounted) return;
      setState(() {
        _camps =
            snap.docs.map((d) => d.data()! as Map<String, dynamic>).toList();
      });
    });
  }

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
        'text': _wmoKoText(code),
        'temp': _avgNum(tmax[idx], tmin[idx]),
        'max': (tmax[idx] as num?)?.toDouble(),
        'min': (tmin[idx] as num?)?.toDouble(),
        'chanceOfRain':
            (prcpProb.isNotEmpty && prcpProb[idx] != null)
                ? (prcpProb[idx] as num).round()
                : null,
      };

      _weatherCache[cacheKey] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

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
          final snap =
              await FirebaseFirestore.instance
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

  Widget _buildFilterDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Drawer(
      width: 320,
      backgroundColor: cs.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  Text(
                    '검색 필터',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: cs.surfaceVariant,
                          foregroundColor: cs.onSurface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: cs.outlineVariant),
                          ),
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
                        child: const Text('초기화'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: cs.primaryContainer,
                          foregroundColor: cs.onPrimaryContainer,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: cs.primary.withOpacity(0.35),
                            ),
                          ),
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
                        child: const Text('적용'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              options.map((opt) {
                final isSelected = selected.contains(opt);
                return ChoiceChip(
                  label: Text(
                    opt,
                    style: TextStyle(
                      color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => onToggle(opt),
                  backgroundColor: cs.surfaceVariant,
                  selectedColor: cs.primaryContainer,
                  side: BorderSide(
                    color:
                        isSelected
                            ? cs.primary.withOpacity(0.50)
                            : cs.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
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
        title: Text(
          '[ $dateLabel 캠핑장 현황 ]',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: cs.surfaceContainerHigh,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    cursorColor: cs.primary,
                    style: TextStyle(color: cs.onSurface),
                    decoration: InputDecoration(
                      hintText: '검색어를 입력하세요',
                      hintStyle: TextStyle(
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: cs.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: cs.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: cs.primary, width: 1.4),
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
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: kElevationToShadow[1],
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color: cs.onPrimary,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                          if (_onlyAvailable) {
                            final avail =
                                (availabilityMap[c['name']]?[dateKey]?['available'] ??
                                        c['available'])
                                    as int? ??
                                0;
                            if (avail <= 0) return false;
                          }
                          return true;
                        }).toList();

                    filtered.sort(
                      (a, b) => _campDistance(a).compareTo(_campDistance(b)),
                    );

                    final baseItems = List.generate(filtered.length, (i) {
                      return {'camp': filtered[i], 'baseIdx': i};
                    });

                    final count = filtered.length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('$count개의 캠핑장이 검색되었어요!'),
                                  const SizedBox(width: 12),
                                  if (_currentPlaceName.isNotEmpty) ...[
                                    Text(
                                      '현위치 : $_currentPlaceName',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 0,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => PlaceSearchScreen(
                                                  onLocationChange:
                                                      updateUserLocation,
                                                ),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        '변경',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  '예약 가능한 캠핑장만 출력',
                                  style: TextStyle(fontSize: 14),
                                ),
                                value: _onlyAvailable,
                                onChanged: (val) {
                                  if (val != null)
                                    setState(() => _onlyAvailable = val);
                                },
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<RatingSort>(
                                segments: const <ButtonSegment<RatingSort>>[
                                  ButtonSegment(
                                    value: RatingSort.none,
                                    label: Text('거리 순'),
                                    icon: Icon(Icons.sort),
                                  ),
                                  ButtonSegment(
                                    value: RatingSort.highFirst,
                                    label: Text('높은 순'),
                                    icon: Icon(Icons.star),
                                  ),
                                  ButtonSegment(
                                    value: RatingSort.lowFirst,
                                    label: Text('낮은 순'),
                                    icon: Icon(Icons.star),
                                  ),
                                ],
                                selected: <RatingSort>{_ratingSort},
                                onSelectionChanged: (newSelection) {
                                  setState(() {
                                    _ratingSort = newSelection.first;
                                  });
                                },
                                style: SegmentedButton.styleFrom(
                                  selectedBackgroundColor: cs.primaryContainer,
                                  selectedForegroundColor:
                                      cs.onPrimaryContainer,
                                  backgroundColor: cs.surfaceVariant,
                                  foregroundColor: cs.onSurface,
                                  side: BorderSide(color: cs.outlineVariant),
                                  shape: const StadiumBorder(),
                                ),
                                showSelectedIcon: false,
                                multiSelectionEnabled: false,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child:
                              (_ratingSort == RatingSort.none)
                                  ? _buildListView(
                                    baseItems,
                                    availabilityMap,
                                    dateKey,
                                  )
                                  : FutureBuilder<Map<String, double?>>(
                                    future: _loadAvgRatingsFor(
                                      baseItems
                                          .take(10)
                                          .map(
                                            (e) =>
                                                e['camp']
                                                    as Map<String, dynamic>,
                                          )
                                          .toList(),
                                    ),
                                    builder: (context, ratingSnap) {
                                      if (!ratingSnap.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      final ratingMap = ratingSnap.data!;
                                      final sorted =
                                          List<Map<String, dynamic>>.from(
                                            baseItems,
                                          );

                                      int cmp(
                                        Map<String, dynamic> a,
                                        Map<String, dynamic> b,
                                      ) {
                                        final ca =
                                            a['camp'] as Map<String, dynamic>;
                                        final cb =
                                            b['camp'] as Map<String, dynamic>;
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
                                            if (diff.abs() > 1e-9)
                                              return -diff.sign.toInt();
                                          } else {
                                            if (diff.abs() > 1e-9)
                                              return diff.sign.toInt();
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
                                      return _buildListView(
                                        sorted,
                                        availabilityMap,
                                        dateKey,
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
        final distance =
            _campDistance(c).isFinite
                ? _campDistance(c).toStringAsFixed(1)
                : '-';

        final contentId = c['contentId']?.toString() ?? '';

        return FutureBuilder<Map<String, dynamic>?>(
          future: fetchWeatherForDate(lat, lng, widget.selectedDate),
          builder: (context, snapshot) {
            final weather = snapshot.data;

            final String weatherText =
                (weather == null)
                    ? ''
                    : '${(weather['temp'] as double?)?.toStringAsFixed(1) ?? '-'}℃'
                        '${weather['chanceOfRain'] != null ? ' · 강수확률 ${weather['chanceOfRain']}%' : ''}';

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
                                  widget.bookmarked[c['name']] == true,
                              onToggleBookmark: widget.onToggleBookmark,
                              selectedDate: widget.selectedDate,
                            ),
                      ),
                    ),
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              c['firstImageUrl'],
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
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    c['name'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    softWrap: true,
                                  ),
                                  if (contentId.isNotEmpty)
                                    _LiveAverageRatingBadge(
                                      contentId: contentId,
                                      dense: true,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${c['location']} | ${c['type']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '거리: $distance km',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              if (weather != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      _wmoIcon(weather['wmo'] as int?),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        weatherText,
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                isAvail
                                    ? '예약 가능 ($avail/$total)'
                                    : '예약 마감 ($avail/$total)',
                                style: TextStyle(
                                  color: isAvail ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            (widget.bookmarked[c['name']] ?? false)
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color:
                                (widget.bookmarked[c['name']] ?? false)
                                    ? Colors.red
                                    : Colors.grey,
                          ),
                          onPressed: () => widget.onToggleBookmark(c['name']),
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
    );
  }
}

class _LiveAverageRatingBadge extends StatelessWidget {
  final String contentId;
  final bool dense;

  const _LiveAverageRatingBadge({required this.contentId, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('campground_reviews')
              .doc(contentId)
              .collection('reviews')
              .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

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
