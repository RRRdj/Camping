import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';

import '../campground_data.dart';
import 'camping_info_screen.dart';
import '../repositories/real_time_availability_repository.dart';
import '../repositories/campground_repository.dart';
import '../services/camp_map_html_service.dart' show CampMapHtmlService;

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
  if (code == 1 || code == 2) return Icons.cloud_queue;
  if (code == 3) return Icons.cloud;
  if (code == 71 || code == 73 || code == 75) return Icons.ac_unit;
  if (code == 95) return Icons.thunderstorm;
  if (code == 61 ||
      code == 63 ||
      code == 65 ||
      code == 80 ||
      code == 81 ||
      code == 82) {
    return Icons.water_drop;
  }
  return Icons.wb_cloudy;
}

final Map<String, Map<String, dynamic>?> _weatherCache = {};
final Map<String, Future<Map<String, dynamic>?>> _weatherFutureCache = {};

Future<Map<String, dynamic>?> _fetchWeatherForDate(
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

  final future = _weatherFutureCache.putIfAbsent(cacheKey, () async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${lat.toStringAsFixed(4)}'
      '&longitude=${lng.toStringAsFixed(4)}'
      '&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_mean'
      '&forecast_days=14'
      '&timezone=auto',
    );

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;

      final decoded = utf8.decode(resp.bodyBytes);
      final data = json.decode(decoded) as Map<String, dynamic>;
      final List times = (data['daily']?['time'] as List?) ?? const [];
      final List codes = (data['daily']?['weathercode'] as List?) ?? const [];
      final List tmax =
          (data['daily']?['temperature_2m_max'] as List?) ?? const [];
      final List tmin =
          (data['daily']?['temperature_2m_min'] as List?) ?? const [];
      final List prcpProb =
          (data['daily']?['precipitation_probability_mean'] as List?) ??
          const [];

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
  });

  final res = await future;
  _weatherFutureCache.remove(cacheKey); // 메모리 누수 방지(완료 후 해제)
  return res;
}

class _LiveAverageRatingBadge extends StatelessWidget {
  final String contentId;
  const _LiveAverageRatingBadge({required this.contentId});

  @override
  Widget build(BuildContext context) {
    if (contentId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
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
        final avgText = (sum / cnt).toStringAsFixed(1);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.amber.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                avgText,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BookmarkScreen extends StatefulWidget {
  final Map<String, bool> bookmarked;
  final void Function(String name) onToggleBookmark;
  final DateTime selectedDate;

  const BookmarkScreen({
    super.key,
    required this.bookmarked,
    required this.onToggleBookmark,
    required this.selectedDate,
  });

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  final _availRepo = RealTimeAvailabilityRepository();
  final _campRepo = CampgroundRepository();
  final _util = CampMapHtmlService();

  late final Future<List<Map<String, dynamic>>> _campsOnce;

  final Map<String, Future<Availability>> _availFutureCache = {};

  @override
  void initState() {
    super.initState();
    _campsOnce = _campRepo.watchCamps().first;
  }

  Future<Availability> _fetchAvailOnce({
    required String name,
    required String dateKey,
  }) {
    final key = '$name|$dateKey';
    return _availFutureCache.putIfAbsent(
      key,
      () => _availRepo.fetchAvailability(campName: name, dateKey: dateKey),
    );
  }

  void _openDetail(
    BuildContext context, {
    required String campName,
    required int available,
    required int total,
    required bool isBookmarked,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CampingInfoScreen(
              campName: campName,
              available: available,
              total: total,
              isBookmarked: isBookmarked,
              onToggleBookmark: widget.onToggleBookmark,
              selectedDate: widget.selectedDate,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkedCamps =
        campgroundList
            .where((camp) => widget.bookmarked[camp['name']] == true)
            .toList();

    if (bookmarkedCamps.isEmpty) {
      return const Center(child: Text('북마크한 캠핑장이 없습니다.'));
    }

    final dateKey = _util.formatDateKey(widget.selectedDate);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _campsOnce,
      builder: (context, campsSnap) {
        if (campsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!campsSnap.hasData) {
          return const SizedBox.shrink();
        }

        final all = campsSnap.data!;
        final Map<String, Map<String, dynamic>> byName = {
          for (final m in all) (m['name'] as String): m,
        };

        return ListView.builder(
          itemCount: bookmarkedCamps.length,
          itemBuilder: (_, i) {
            final camp = bookmarkedCamps[i];
            final name = camp['name'] as String;

            return FutureBuilder<Availability>(
              future: _fetchAvailOnce(name: name, dateKey: dateKey),
              builder: (context, snap1) {
                final availData = snap1.data;
                final available = availData?.available ?? 0;
                final total = availData?.total ?? 0;
                final isAvail = available > 0;

                final matching = byName[name] ?? const <String, dynamic>{};
                final location = matching['location'] as String? ?? '-';
                final type = matching['type'] as String? ?? '-';
                final img = (matching['firstImageUrl'] as String?) ?? '';
                final hasImage = img.isNotEmpty;
                final contentId = matching['contentId']?.toString() ?? '';
                final lat =
                    double.tryParse((matching['mapY'] as String?) ?? '') ?? 0.0;
                final lng =
                    double.tryParse((matching['mapX'] as String?) ?? '') ?? 0.0;

                return FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchWeatherForDate(lat, lng, widget.selectedDate),
                  builder: (context, wsnap) {
                    final weather = wsnap.data;
                    final waiting =
                        snap1.connectionState == ConnectionState.waiting;

                    if (waiting) {
                      return _BookmarkSkeletonCard();
                    }

                    final isBookmarked = widget.bookmarked[name] == true;

                    return Opacity(
                      opacity: isAvail ? 1 : 0.45,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          _openDetail(
                            context,
                            campName: name,
                            available: available,
                            total: total,
                            isBookmarked: isBookmarked,
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasImage)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      img,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      cacheWidth: 120,
                                      cacheHeight: 120,
                                      errorBuilder:
                                          (_, __, ___) =>
                                              const _ImageFallback(),
                                    ),
                                  )
                                else
                                  const _ImageFallback(),
                                const SizedBox(width: 16),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            softWrap: true,
                                          ),
                                          if (contentId.isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.star,
                                                  size: 16,
                                                  color: Colors.amber,
                                                ),
                                                const SizedBox(width: 4),
                                                _AverageRatingText(
                                                  contentId: contentId,
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$location | $type',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      if (weather != null)
                                        Row(
                                          children: [
                                            Icon(
                                              _wmoIcon(weather['wmo'] as int?),
                                              size: 18,
                                              color: Colors.teal,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '${(weather['temp'] as double?)?.toStringAsFixed(1) ?? '-'}℃'
                                                '${weather['chanceOfRain'] != null ? ' · 강수확률 ${weather['chanceOfRain']}%' : ''}'
                                                ' · ${_wmoKoText(weather['wmo'] as int?)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 6),

                                      Text(
                                        isAvail
                                            ? '예약 가능 ($available/$total)'
                                            : '예약 마감 ($available/$total)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              isAvail
                                                  ? Colors.green
                                                  : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                IconButton(
                                  icon: const Icon(
                                    Icons.bookmark,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    widget.onToggleBookmark(name);
                                    setState(() {});
                                  },
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
          },
        );
      },
    );
  }
}

class _BookmarkSkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(height: 16, width: 120, color: Colors.white),
                        const SizedBox(width: 8),
                        Container(height: 14, width: 36, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 140, color: Colors.white),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(width: 18, height: 18, color: Colors.white),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(height: 12, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 90, color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 24, height: 24, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _AverageRatingText extends StatelessWidget {
  final String contentId;
  const _AverageRatingText({required this.contentId});

  @override
  Widget build(BuildContext context) {
    if (contentId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
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
        final avgText = (sum / cnt).toStringAsFixed(1);
        return Text(
          avgText,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        );
      },
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.park, size: 48, color: Colors.teal);
  }
}
