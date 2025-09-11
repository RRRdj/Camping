// lib/screens/camping_info_screen.dart
// ignore_for_file: library_private_types_in_public_api

import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../repositories/camp_repository.dart';
import '../services/go_camping_service.dart';
import '../widgets/amenity_section.dart';
import '../widgets/info_row.dart';
import '../widgets/review_form.dart';
import '../widgets/weather_summary_chip.dart';

import '../widgets/weather_presenter.dart';
import '../widgets/memo_box.dart';
import '../widgets/reservation_action_buttons.dart';
import '../widgets/detail_info_section.dart';
import '../widgets/kakao_map_view.dart';
import '../widgets/site_button.dart';

import 'camping_reservation_screen.dart';
import 'reservation_info_screen.dart';
import 'camping_weather_forecast_screen.dart';

/* ───────────────── 정렬 타입 ───────────────── */
enum ReviewSort { newest, ratingHigh, ratingLow }

class CampingInfoScreen extends StatefulWidget {
  final String campName;
  final int available;
  final int total;
  final bool isBookmarked;
  final void Function(String campName) onToggleBookmark;
  final DateTime selectedDate;

  const CampingInfoScreen({
    super.key,
    required this.campName,
    required this.available,
    required this.total,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.selectedDate,
  });

  @override
  State<CampingInfoScreen> createState() => _CampingInfoScreenState();
}

class _CampingInfoScreenState extends State<CampingInfoScreen> {
  final _repo = CampRepository();
  final _service = GoCampingService();

  final ImagePicker _picker = ImagePicker();
  List<XFile> _pickedImages = [];

  late Future<DocumentSnapshot<Map<String, dynamic>>> _campFuture;
  late Future<List<String>> _imagesFuture;
  late bool _bookmarked;

  // 리뷰 입력
  final _txtCtr = TextEditingController();
  int _rating = 5;

  // 메모
  final _memoCtr = TextEditingController();
  String _memoText = '';
  String? _contentId;
  String? _userNickname;

  // 리뷰 필터 상태
  ReviewSort _reviewSort = ReviewSort.newest;
  bool _photoOnly = false;

  // ───────────── 날씨 ─────────────
  static final Map<String, Map<String, dynamic>?> _weatherCache = {};
  Future<Map<String, dynamic>?>? _weatherFuture;

  /*──────────────── 메모 로드 ────────────────*/
  Future<void> _loadSavedMemo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _contentId == null || _contentId!.isEmpty) return;

    final snap =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reservation_memos')
            .doc(_contentId)
            .get();

    if (snap.exists) {
      setState(() => _memoText = (snap.data()?['memo'] ?? '') as String);
    }
  }

  /*──────────────── initState ────────────────*/
  @override
  void initState() {
    super.initState();
    _bookmarked = widget.isBookmarked;

    _campFuture = _repo.getCamp(widget.campName);
    _imagesFuture = _campFuture.then((doc) async {
      final data = doc.data()!;
      final cid = data['contentId']?.toString() ?? '';
      _contentId = cid;
      await _loadSavedMemo();

      final firstUrl = data['firstImageUrl'] as String?;
      return _service.fetchImages(cid, firstUrl);
    });

    // 초기 날씨 Future 설정
    _weatherFuture = _campFuture.then((doc) {
      final c = doc.data()!;
      final lat = double.tryParse((c['mapY'] as String?) ?? '') ?? 0.0;
      final lng = double.tryParse((c['mapX'] as String?) ?? '') ?? 0.0;
      return fetchWeatherForDate(lat, lng, widget.selectedDate);
    });

    _loadUserNickname();
  }

  @override
  void didUpdateWidget(covariant CampingInfoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 날짜나 캠핑장이 바뀌면 날씨 갱신
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.campName != widget.campName) {
      _weatherFuture = _campFuture.then((doc) {
        final c = doc.data()!;
        final lat = double.tryParse((c['mapY'] as String?) ?? '') ?? 0.0;
        final lng = double.tryParse((c['mapX'] as String?) ?? '') ?? 0.0;
        return fetchWeatherForDate(lat, lng, widget.selectedDate);
      });
      setState(() {});
    }
  }

  @override
  void dispose() {
    _txtCtr.dispose();
    _memoCtr.dispose();
    super.dispose();
  }

  Future<void> _loadUserNickname() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final nick = await _repo.getUserNickname(user.uid);
    setState(() => _userNickname = nick);
  }

  /*──────────────── 메모 편집 다이얼로그 ────────────────*/
  Future<void> _showEditDialog() async {
    _memoCtr.text = _memoText;
    final result = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('메모 수정'),
            content: TextField(
              controller: _memoCtr,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '메모를 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _memoCtr.text.trim()),
                child: const Text('확인'),
              ),
            ],
          ),
    );

    if (result == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _contentId != null && _contentId!.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reservation_memos')
          .doc(_contentId)
          .set({
            'campName': widget.campName,
            'contentId': _contentId,
            'memo': result,
            'savedAt': DateTime.now(),
          });
    }
    setState(() => _memoText = result);
    _showMsg('메모가 저장되었습니다.');
  }

  /*──────────────── 알림 설정 ────────────────*/
  Future<void> _onTapAlarm() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _showMsg('로그인 후 이용해주세요.');

    final count = await _repo.alarmsCount(user.uid);
    if (count >= 5) return _showMsg('알림은 최대 5개까지 설정할 수 있어요.');

    await showDialog(
      context: context,
      builder:
          (ctx) => const AlertDialog(
            title: Text('알림 설정 안내'),
            content: Text('알림을 받고 싶은 날짜를 선택하세요.\n선택한 날짜에 빈자리가 생기면 알려드릴게요!'),
          ),
    );

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('ko'), // ① 다이얼로그 자체 로케일 지정
      helpText: '날짜 선택', // ② 텍스트도 한국어로
      cancelText: '취소',
      confirmText: '확인',
      builder:
          (context, child) => // ③ 이 컨텍스트만 한국어로 강제
              Localizations.override(
            context: context,
            locale: const Locale('ko'),
            child: child,
          ),
    );

    if (selectedDate == null) return;

    await _repo.addAlarm(
      campName: widget.campName,
      contentId: _contentId,
      date: selectedDate,
    );
    _showMsg('${DateFormat('M월 d일').format(selectedDate)} 알림이 설정되었습니다.');
  }

  /*──────────────── 이미지 선택 ────────────────*/
  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      setState(() => _pickedImages = images);
    }
  }

  /*──────────────── 리뷰 등록 ────────────────*/
  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _showMsg('로그인 후 이용 가능합니다.');
    if (_txtCtr.text.trim().isEmpty) return _showMsg('내용을 입력하세요.');
    if ((_contentId ?? '').isEmpty) return _showMsg('캠핑장 정보 오류');

    await _repo.addReview(
      contentId: _contentId!,
      campName: widget.campName,
      rating: _rating,
      content: _txtCtr.text.trim(),
      imageFiles: _pickedImages,
    );

    _txtCtr.clear();
    setState(() {
      _rating = 5;
      _pickedImages = [];
    });
    _showMsg('리뷰가 등록되었습니다.');
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ───────────── Open-Meteo 하루치 날씨(홈과 동일 로직) ─────────────
  Future<Map<String, dynamic>?> fetchWeatherForDate(
    double lat,
    double lng,
    DateTime date,
  ) async {
    DateTime just(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
    final d = just(date);
    final today = just(DateTime.now());
    final diffDays = d.difference(today).inDays;

    if (diffDays < 0 || diffDays > 13) return null; // 과거/14일 이후 제외

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
        'text': wmoKoText(code),
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

  /*──────────────────────────────────────────*/
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final dateLabel = DateFormat('MM월 dd일').format(widget.selectedDate);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _campFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData || !snap.data!.exists) {
              return const Center(child: Text('캠핑장 정보를 불러올 수 없습니다.'));
            }

            // Firestore 데이터
            final c = snap.data!.data()!;
            final isAvail = widget.available > 0;
            final amenities =
                (c['amenities'] as List<dynamic>?)?.cast<String>() ?? [];
            _contentId ??= c['contentId']?.toString() ?? '';

            final double latitude =
                double.tryParse((c['mapY'] as String?) ?? '') ?? 0.0;
            final double longitude =
                double.tryParse((c['mapX'] as String?) ?? '') ?? 0.0;
            final String name = c['name'] as String? ?? widget.campName;

            return CustomScrollView(
              slivers: [
                /*──────── SliverAppBar + 이미지 페이저 ────────*/
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 250,
                  backgroundColor: Colors.teal,
                  flexibleSpace: FlexibleSpaceBar(
                    background: FutureBuilder<List<String>>(
                      future: _imagesFuture,
                      builder: (_, imgSnap) {
                        final imgs = imgSnap.data ?? [];
                        if (imgs.isEmpty) {
                          return Container(color: Colors.grey.shade200);
                        }
                        return PageView.builder(
                          itemCount: imgs.length,
                          itemBuilder:
                              (_, i) =>
                                  Image.network(imgs[i], fit: BoxFit.cover),
                        );
                      },
                    ),
                  ),
                ),

                /*──────── 본문 ────────*/
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 12),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      /* 캠핑장명 + (실시간 평균 별점) + 공유 + 북마크 */
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // 캠핑장 이름 (줄바꿈 허용, 생략 없음)
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  softWrap: true,
                                ),
                                // ⭐ 실시간 평균 별점 배지
                                if ((_contentId ?? '').isNotEmpty)
                                  _LiveAverageRatingBadge(
                                    contentId: _contentId!,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.teal),
                            tooltip: '카카오맵 링크 공유',
                            onPressed: () async {
                              final encoded = Uri.encodeComponent(name);
                              final url =
                                  'https://map.kakao.com/link/to/$encoded,$latitude,$longitude';
                              try {
                                await Share.share(url, subject: '$name 위치 공유');
                              } catch (e) {
                                _showMsg('공유 실패: $e');
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              _bookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: _bookmarked ? Colors.red : Colors.grey,
                            ),
                            onPressed: () {
                              setState(() => _bookmarked = !_bookmarked);
                              widget.onToggleBookmark(name);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      /* 예약 가능 상태 */
                      Text(
                        '$dateLabel ${isAvail ? '예약 가능' : '예약 마감'} '
                        '(${widget.available}/${widget.total})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isAvail ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),

                      FutureBuilder<Map<String, dynamic>?>(
                        future: _weatherFuture,
                        builder: (context, wsnap) {
                          final w = wsnap.data;
                          if (wsnap.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(
                              height: 20,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (w == null) return const SizedBox.shrink();

                          return Row(
                            children: [
                              WeatherSummaryChip(
                                wmo: w['wmo'] as int?,
                                temp: w['temp'] as double?,
                                pop: w['chanceOfRain'] as int?,
                              ),
                              const SizedBox(width: 8),
                              ActionChip(
                                avatar: const Icon(
                                  Icons.cloud_outlined,
                                  size: 18,
                                  color: Colors.teal,
                                ),
                                label: const Text('날씨정보'),
                                onPressed:
                                    (latitude == 0.0 && longitude == 0.0)
                                        ? null
                                        : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) =>
                                                      CampingWeatherForecastScreen(
                                                        lat: latitude,
                                                        lng: longitude,
                                                      ),
                                            ),
                                          );
                                        },
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      /* ─── 예약/정보/알림 버튼 묶음 ─── */
                      ReservationActionButtons(
                        onSchedule:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => CampingReservationScreen(
                                      camp: {'name': name},
                                    ),
                              ),
                            ),
                        onInfo:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReservationInfoScreen(),
                                settings: RouteSettings(
                                  arguments: {
                                    'campName': name,
                                    'contentId': _contentId,
                                    'campType': c['type'],
                                  },
                                ),
                              ),
                            ),
                        onAlarm: _onTapAlarm,
                      ),

                      /* 메모 */
                      const SizedBox(height: 24),
                      MemoBox(memoText: _memoText, onEdit: _showEditDialog),
                      const SizedBox(height: 24),

                      /* ─── 관련 사이트 버튼 ─── */
                      SiteButton(siteUrl: c['site'] as String?),

                      const Divider(height: 32),

                      /* 정보 행들 */
                      Row(
                        children: [
                          Expanded(
                            child: InfoRow(
                              label: '주소',
                              value: c['addr1'] ?? '정보없음',
                              icon: Icons.location_on,
                              color: Colors.teal,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.grey),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: c['addr1'] ?? ''),
                              );
                              _showMsg('주소가 복사되었습니다.');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      /* 카카오 지도 위젯 */
                      KakaoMapView(lat: latitude, lng: longitude),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: InfoRow(
                              label: '전화번호',
                              value: c['tel'] ?? '정보없음',
                              icon: Icons.phone,
                              color: Colors.teal,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.grey),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: c['tel'] ?? ''),
                              );
                              _showMsg('전화번호가 복사되었습니다.');
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.phone_outlined,
                              color: Colors.teal,
                            ),
                            onPressed: () => _launchDialer(c['tel'] ?? ''),
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      InfoRow(
                        label: '캠핑장 유형',
                        value: c['type'] ?? '정보없음',
                        icon: Icons.circle,
                        color: Colors.teal,
                      ),
                      InfoRow(
                        label: '캠핑장 구분',
                        value: c['inDuty'] ?? '정보없음',
                        icon: Icons.event_note,
                        color: Colors.blueGrey,
                      ),
                      if ((c['lctCl'] ?? '').isNotEmpty)
                        InfoRow(
                          label: '환경',
                          value: c['lctCl'],
                          icon: Icons.nature,
                          color: Colors.brown,
                        ),
                      const Divider(height: 32),
                      AmenitySection(amenities: amenities),
                      const Divider(height: 32),

                      /* 상세 정보 섹션 */
                      const Text(
                        '기본 정보',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DetailInfoSection(
                        lineIntro: c['lineIntro'],
                        intro: c['intro'],
                        featureNm: c['featureNm'],
                      ),
                      const Divider(height: 32),

                      /* ───────── 리뷰 작성 폼 ───────── */
                      ReviewForm(
                        txtCtr: _txtCtr,
                        rating: _rating,
                        userNickname: _userNickname,
                        onRating: (v) => setState(() => _rating = v),
                        onPickImages: _pickImages,
                        selectedImages: _pickedImages,
                        onRemoveImage: (index) {
                          setState(() => _pickedImages.removeAt(index));
                        },
                        onSubmit: _submitReview,
                      ),

                      const Divider(height: 24),

                      /* ───────── 리뷰 필터 바 + 목록 (필터 반영) ───────── */
                      if ((_contentId ?? '').isNotEmpty) ...[
                        _ReviewFilterBar(
                          sort: _reviewSort,
                          photoOnly: _photoOnly,
                          onSortChanged: (v) => setState(() => _reviewSort = v),
                          onPhotoOnlyChanged:
                              (v) => setState(() => _photoOnly = v),
                        ),
                        const SizedBox(height: 12),
                        _FilteredReviewList(
                          contentId: _contentId!,
                          sort: _reviewSort,
                          photoOnly: _photoOnly,
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _launchDialer(String num) async {
    final uri = Uri(scheme: 'tel', path: num);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showMsg('전화 앱을 열 수 없습니다.');
    }
  }
}

/* ======================= ⭐ 실시간 평균 별점 배지 위젯 ==================== */
class _LiveAverageRatingBadge extends StatelessWidget {
  final String contentId;
  const _LiveAverageRatingBadge({required this.contentId});

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

        final avg = (sum / cnt);
        final avgText = avg.toStringAsFixed(1); // 소수점 첫째자리

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
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ======================= 리뷰 필터 바 ==================== */
class _ReviewFilterBar extends StatelessWidget {
  final ReviewSort sort;
  final bool photoOnly;
  final ValueChanged<ReviewSort> onSortChanged;
  final ValueChanged<bool> onPhotoOnlyChanged;

  const _ReviewFilterBar({
    required this.sort,
    required this.photoOnly,
    required this.onSortChanged,
    required this.onPhotoOnlyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<ReviewSort>(
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: ReviewSort.newest, label: Text('최신순')),
            ButtonSegment(
              value: ReviewSort.ratingHigh,
              icon: Icon(Icons.star),
              label: Text('높은 순'),
            ),
            ButtonSegment(
              value: ReviewSort.ratingLow,
              icon: Icon(Icons.star),
              label: Text('낮은 순'),
            ),
          ],
          selected: {sort},
          onSelectionChanged: (s) {
            if (s.isNotEmpty) onSortChanged(s.first);
          },
        ),
        FilterChip(
          label: const Text('사진 리뷰만 보기'),
          selected: photoOnly,
          onSelected: onPhotoOnlyChanged,
          selectedColor: Colors.teal.withOpacity(0.15),
          checkmarkColor: Colors.teal,
        ),
      ],
    );
  }
}

/* ======================= 필터 적용 리뷰 목록 (총 개수 표시 포함) ==================== */
class _FilteredReviewList extends StatelessWidget {
  final String contentId;
  final ReviewSort sort;
  final bool photoOnly;

  const _FilteredReviewList({
    required this.contentId,
    required this.sort,
    required this.photoOnly,
  });

  bool _hasPhotos(Map<String, dynamic> m) {
    for (final key in ['images', 'imageUrls', 'photos']) {
      final v = m[key];
      if (v is List && v.isNotEmpty) return true;
    }
    return false;
  }

  List<String> _extractPhotos(Map<String, dynamic> m) {
    for (final key in ['images', 'imageUrls', 'photos']) {
      final v = m[key];
      if (v is List) {
        return v.whereType<String>().toList();
      }
    }
    return const [];
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

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
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Text('아직 등록된 리뷰가 없습니다.');
        }

        final items =
            docs.map((d) {
              final m = d.data() as Map<String, dynamic>;
              return {...m, '_id': d.id};
            }).toList();

        final totalCount = items.length;
        final filtered = photoOnly ? items.where(_hasPhotos).toList() : items;

        filtered.sort((a, b) {
          final ar = (a['rating'] as num?)?.toDouble() ?? 0.0;
          final br = (b['rating'] as num?)?.toDouble() ?? 0.0;
          final ad =
              _toDate(a['date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd =
              _toDate(b['date']) ?? DateTime.fromMillisecondsSinceEpoch(0);

          switch (sort) {
            case ReviewSort.newest:
              return bd.compareTo(ad);
            case ReviewSort.ratingHigh:
              final cmp = br.compareTo(ar);
              return cmp != 0 ? cmp : bd.compareTo(ad);
            case ReviewSort.ratingLow:
              final cmp = ar.compareTo(br);
              return cmp != 0 ? cmp : bd.compareTo(ad);
          }
        });

        final shownCount = filtered.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                shownCount == totalCount
                    ? '총 리뷰 ${totalCount}개'
                    : '총 리뷰 ${totalCount}개 · 사진 리뷰 ${shownCount}개',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (ctx, i) {
                final m = filtered[i];
                final reviewId = m['_id'] as String;
                final nick = (m['nickname'] as String?) ?? '익명';
                final date = _toDate(m['date']);
                final dateStr =
                    date != null ? DateFormat('yyyy-MM-dd').format(date) : '';
                final rating = (m['rating'] as num?)?.toInt() ?? 5;
                final content = (m['content'] as String?) ?? '';
                final photos = _extractPhotos(m);

                final currentUser = FirebaseAuth.instance.currentUser;
                final reviewerId = (m['userId'] as String?) ?? '';

                List<Widget> actions = [];
                if (currentUser != null && reviewerId == currentUser.uid) {
                  actions = [
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.teal,
                      ),
                      tooltip: '수정',
                      onPressed:
                          () => _showEditDialog(
                            context,
                            reviewId: reviewId,
                            oldRating: rating,
                            oldContent: content,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                      tooltip: '삭제',
                      onPressed: () => _showDeleteDialog(context, reviewId),
                    ),
                  ];
                } else if (currentUser != null) {
                  actions = [
                    IconButton(
                      icon: const Icon(
                        Icons.flag,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      tooltip: '신고',
                      onPressed:
                          () => _showReportDialog(
                            context,
                            reviewId: reviewId,
                            reportedUserId: reviewerId,
                          ),
                    ),
                  ];
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            nick,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        ...actions,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating ? Icons.star : Icons.star_border,
                          color: Colors.green,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(content),
                    if (photos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children:
                            photos
                                .map(
                                  (url) => ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  /* ───── 편집 / 삭제 / 신고 다이얼로그 및 동작 ───── */
  Future<void> _showEditDialog(
    BuildContext context, {
    required String reviewId,
    required int oldRating,
    required String oldContent,
  }) async {
    final contentCtrl = TextEditingController(text: oldContent);
    int newRating = oldRating;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('리뷰 수정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: newRating,
                  items:
                      List.generate(
                        5,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1}'),
                        ),
                      ).toList(),
                  onChanged: (v) {
                    if (v != null) newRating = v;
                  },
                ),
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '내용'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('확인'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews')
          .doc(reviewId)
          .update({
            'rating': newRating,
            'content': contentCtrl.text.trim(),
            'date': FieldValue.serverTimestamp(),
          });
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('리뷰 삭제'),
            content: const Text('이 리뷰를 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews')
          .doc(reviewId)
          .delete();
    }
  }

  Future<void> _showReportDialog(
    BuildContext context, {
    required String reviewId,
    required String reportedUserId,
  }) async {
    final reporter = FirebaseAuth.instance.currentUser;
    if (reporter == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 이용해주세요.')));
      return;
    }

    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('신고 사유 입력'),
            content: TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '신고 사유를 입력하세요'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
                child: const Text('확인'),
              ),
            ],
          ),
    );
    if (reason == null || reason.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('신고 확인'),
            content: const Text('이 리뷰를 신고하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('신고'),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(reporter.uid)
            .get();
    final reporterNickname = userDoc.data()?['nickname'] as String? ?? '';

    final batch = FirebaseFirestore.instance.batch();
    final reportRef =
        FirebaseFirestore.instance.collection('review_reports').doc();
    batch.set(reportRef, {
      'contentId': contentId,
      'reviewId': reviewId,
      'reportedUserId': reportedUserId,
      'reporterUid': reporter.uid,
      'reporterEmail': reporter.email ?? '',
      'reporterNickname': reporterNickname,
      'reason': reason,
      'date': FieldValue.serverTimestamp(),
    });

    final reviewDocRef = FirebaseFirestore.instance
        .collection('campground_reviews')
        .doc(contentId)
        .collection('reviews')
        .doc(reviewId);
    batch.update(reviewDocRef, {'reportCount': FieldValue.increment(1)});

    await batch.commit();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
  }
}

double? _avgNum(dynamic a, dynamic b) {
  if (a == null || b == null) return null;
  return ((a as num).toDouble() + (b as num).toDouble()) / 2.0;
}
