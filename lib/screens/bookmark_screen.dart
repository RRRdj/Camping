// lib/screens/bookmark_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart'; // 👈 추가

import '../campground_data.dart';
import 'camping_info_screen.dart';
import '../repositories/real_time_availability_repository.dart';
import '../repositories/campground_repository.dart';
import '../services/camp_map_html_service.dart';

/* ───────────── 날씨 헬퍼 & 캐시 ───────────── */
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

final Map<String, Map<String, dynamic>?> _weatherCache = {};

Future<Map<String, dynamic>?> _fetchWeatherForDate(
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

/* ───────────── 평균 별점 배지(실시간) ───────────── */
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
            children: const [Icon(Icons.star, size: 16, color: Colors.amber)],
          ),
        );
      },
    );
  }
}

/* ───────────── 화면 본문 ───────────── */
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

    return ListView.builder(
      itemCount: bookmarkedCamps.length,
      itemBuilder: (_, i) {
        final camp = bookmarkedCamps[i];
        final name = camp['name'] as String;

        return FutureBuilder<Availability>(
          future: _availRepo.fetchAvailability(
            campName: name,
            dateKey: dateKey,
          ),
          builder: (context, snap1) {
            final availData = snap1.data;
            final available = availData?.available ?? 0;
            final total = availData?.total ?? 0;
            final isAvail = available > 0;

            // 여기서는 watchCamps를 한 번 불러 현재 스냅샷에서 상세정보를 가져와 쓴다.
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _campRepo.watchCamps().first,
              builder: (context, snap2) {
                if (snap2.connectionState == ConnectionState.waiting) {
                  // ✅ Shimmer를 Card "안쪽 내용"에만 적용한다.
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // (선택) 머티리얼3에서 색 틴트가 들어갈 경우 아래 두 줄로 톤 중립화
                    surfaceTintColor: Colors.transparent,
                    color: Theme.of(context).cardColor,
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 이미지 자리 ──
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white, // ← 스켈레톤 블럭 (불투명)
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // ── 본문 자리 ──
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 제목 + 별점 자리 (두 블럭)
                                  Row(
                                    children: [
                                      Container(
                                        height: 16,
                                        width: 120,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        height: 14,
                                        width: 36,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // 위치/타입
                                  Container(
                                    height: 12,
                                    width: 140,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 8),

                                  // 날씨 (아이콘 + 텍스트)
                                  Row(
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Container(
                                          height: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // 예약 상태
                                  Container(
                                    height: 12,
                                    width: 90,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // ── 북마크 아이콘 자리 ──
                            Container(
                              width: 24,
                              height: 24,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                if (!snap2.hasData) {
                  return const SizedBox.shrink();
                }

                final all = snap2.data!;
                final matching = all.firstWhere(
                  (m) => m['name'] == name,
                  orElse: () => <String, dynamic>{},
                );

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

                    return Opacity(
                      opacity: isAvail ? 1 : 0.4,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 이미지/아이콘
                              if (hasImage)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    img,
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

                              // 본문
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 제목 + 별점
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
                                    // 날씨 요약
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
                                    // 예약 가능 상태
                                    Text(
                                      isAvail
                                          ? '예약 가능 ($available/$total)'
                                          : '예약 마감 ($available/$total)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            isAvail ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 북마크 해제 버튼
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

/* ───────────── 평균 별점 숫자(Text) ───────────── */
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
