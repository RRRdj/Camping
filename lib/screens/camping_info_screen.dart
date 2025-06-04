// lib/screens/camping_info_screen.dart
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../repositories/camp_repository.dart';
import '../services/go_camping_service.dart';
import '../widgets/amenity_section.dart';
import '../widgets/expandable_text.dart';
import '../widgets/info_row.dart';
import '../widgets/review_form.dart';
import '../widgets/review_section.dart';

// ★ 새로 만든 위젯들
import '../widgets/memo_box.dart';
import '../widgets/reservation_action_buttons.dart';
import '../widgets/detail_info_section.dart';
import '../widgets/kakao_map_view.dart';
import '../widgets/site_button.dart';

import 'camping_reservation_screen.dart';
import 'reservation_info_screen.dart';

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

    _loadUserNickname();
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
    );
    if (selectedDate == null) return;

    await _repo.addAlarm(
      campName: widget.campName,
      contentId: _contentId,
      date: selectedDate,
    );
    _showMsg('${DateFormat('M월 d일').format(selectedDate)} 알림이 설정되었습니다.');
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
    );

    _txtCtr.clear();
    setState(() => _rating = 5);
    _showMsg('리뷰가 등록되었습니다.');
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                      /* 캠핑장명 + 공유 + 북마크 */
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
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
                      const SizedBox(height: 12),

                      /* ─── 새로 추출한 ReservationActionButtons ─── */
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

                      /* ─── 관련 사이트 버튼 추출 ─── */
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

                      /* 리뷰 */
                      ReviewForm(
                        txtCtr: _txtCtr,
                        rating: _rating,
                        userNickname: _userNickname,
                        onRating: (v) => setState(() => _rating = v),
                        onSubmit: _submitReview,
                      ),
                      const Divider(height: 32),
                      ReviewSection(
                        repository: _repo,
                        contentId: _contentId ?? '',
                      ),
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
