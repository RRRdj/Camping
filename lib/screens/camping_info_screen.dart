// lib/screens/camping_info_screen.dart
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart'; // ★ share_plus 임포트
import 'package:camping/screens/camping_reservation_screen.dart';
import 'package:camping/screens/reservation_info_screen.dart';
import 'package:camping/widgets/expandable_text.dart';
import 'package:camping/widgets/info_row.dart';
import 'package:camping/widgets/review_section.dart';
import 'package:camping/widgets/amenity_section.dart';
import 'package:camping/widgets/review_form.dart';

import '../repositories/camp_repository.dart';
import '../services/go_camping_service.dart';

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
  _CampingInfoScreenState createState() => _CampingInfoScreenState();
}

class _CampingInfoScreenState extends State<CampingInfoScreen> {
  final _repo = CampRepository();
  final _service = GoCampingService();

  late Future<DocumentSnapshot<Map<String, dynamic>>> _campFuture;
  late Future<List<String>> _imagesFuture;
  late bool _bookmarked;

  // ─── 리뷰 입력 ───
  final TextEditingController _txtCtr = TextEditingController();
  int _rating = 5;

  // ─── 메모 기능 ───
  final TextEditingController _memoCtr = TextEditingController();
  String _memoText = '';

  String? _contentId;
  String? _userNickname;

  // ─── (1) 메모 로드 함수 추가 ───
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

  // ─── (2) initState 안에서 캠핑장 정보 로드 후 메모도 함께 로드 ───
  @override
  void initState() {
    super.initState();
    _bookmarked = widget.isBookmarked;

    _campFuture = _repo.getCamp(widget.campName);
    _imagesFuture = _campFuture.then((doc) async {
      final data = doc.data()!;
      final cid = data['contentId']?.toString() ?? '';
      _contentId = cid;

      await _loadSavedMemo(); // ← 추가 : 저장된 메모 불러오기

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

  // ─── 메모 수정용 다이얼로그 ───
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

    if (result != null) {
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
  }

  // ─── 알림 설정 ───
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

  // ─── 리뷰 등록 ───
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

            // Firestore에서 가져온 캠핑장 데이터
            final c = snap.data!.data()!;
            final isAvail = widget.available > 0;
            final amenities =
                (c['amenities'] as List<dynamic>?)?.cast<String>() ?? [];
            _contentId ??= c['contentId']?.toString() ?? '';

            // 캠핑장 위도/경도 (문자열 → double 파싱)
            final double latitude =
                double.tryParse((c['mapY'] as String?) ?? '') ?? 0.0;
            final double longitude =
                double.tryParse((c['mapX'] as String?) ?? '') ?? 0.0;
            final String name = c['name'] as String? ?? widget.campName;

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 250,
                  backgroundColor: Colors.teal,

                  // ─── 여기에 SliverAppBar의 actions에 공유 버튼 추가 ───
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

                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 12),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ─── 캠핑장 제목, 공유 아이콘, 즐겨찾기 ───
                      // ─── ② 제목 · 공유 · 북마크 Row (통째로 교체) ───
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
                          // 공유 버튼 ― 북마크 왼쪽
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.teal),
                            tooltip: '카카오맵 링크 공유',
                            onPressed: () async {
                              final encodedName = Uri.encodeComponent(name);
                              final kakaoMapUrl =
                                  'https://map.kakao.com/link/to/$encodedName,$latitude,$longitude';
                              try {
                                await Share.share(
                                  kakaoMapUrl,
                                  subject: '$name 위치 공유',
                                );
                              } catch (e) {
                                _showMsg('공유를 진행할 수 없습니다: $e');
                              }
                            },
                          ),
                          // 북마크 버튼
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
                      // ─── 예약 상태 ───
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
                      // ─── 예약/정보/알림 버튼 ───
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: const Text('예약 현황'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => CampingReservationScreen(
                                        camp: {'name': name},
                                      ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.info_outline),
                            label: const Text('예약정보'),
                            onPressed: () {
                              Navigator.push(
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
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                            ),
                            label: const Text('알림'),
                            onPressed: _onTapAlarm,
                          ),
                        ],
                      ),

                      // ──────────────────────
                      //          메모 영역
                      // ──────────────────────
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _memoText.isNotEmpty
                                    ? _memoText
                                    : '잊기 쉬운 내용을 남겨주세요!',
                                style: TextStyle(
                                  color:
                                      _memoText.isNotEmpty
                                          ? Colors.black
                                          : Colors.grey,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: _showEditDialog,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ─── 예약하기 버튼 ───
                      ElevatedButton(
                        onPressed: () async {
                          final type = c['type'];
                          String? url =
                              type == '국립'
                                  ? 'https://reservation.knps.or.kr/reservation/searchSimpleCampReservation.do'
                                  : c['resveUrl'];
                          if (url == null || url.isEmpty) {
                            return _showMsg(
                              '예약 페이지가 없습니다.\n전화로 문의하세요: ${c['tel'] ?? '-'}',
                            );
                          }
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            _showMsg('페이지를 열 수 없습니다.');
                          }
                        },
                        child: const Text('예약하기'),
                      ),
                      const Divider(height: 32),

                      // ─── 정보 표시 영역 ───
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
                      _buildKakaoMap(c),
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
                            onPressed: () {
                              _launchDialer(c['tel'] ?? '');
                            },
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

                      // ─── 상세 정보 ───
                      Text(
                        '기본 정보',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailInfo(c),
                      const SizedBox(height: 12),
                      _buildSiteButton(c),
                      const Divider(height: 32),

                      // ─── 리뷰 작성 및 목록 ───
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

  Widget _buildDetailInfo(Map<String, dynamic> c) {
    if (((c['lineIntro'] as String?)?.isNotEmpty ?? false) ||
        ((c['intro'] as String?)?.isNotEmpty ?? false) ||
        ((c['featureNm'] as String?)?.isNotEmpty ?? false)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((c['lineIntro'] as String?)?.isNotEmpty ?? false)
            ExpandableText(c['lineIntro'], trimLines: 3),
          const SizedBox(height: 4),
          ExpandableText(
            (c['intro'] as String?)?.isNotEmpty ?? false
                ? c['intro']
                : (c['featureNm'] as String? ?? ''),
            trimLines: 5,
          ),
        ],
      );
    }
    return const Text(
      '자세한 정보를 찾으시려면 예약현황이나 사이트를 통해서 확인하세요.',
      style: TextStyle(color: Colors.grey),
    );
  }

  Widget _buildSiteButton(Map<String, dynamic> c) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
      onPressed: () async {
        final siteUrl = c['site'] as String?;
        if (siteUrl == null || siteUrl.isEmpty) {
          return _showMsg('사이트 정보가 없습니다.');
        }
        final uri = Uri.parse(siteUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showMsg('사이트를 열 수 없습니다.');
        }
      },
      child: const Text('관련 사이트', style: TextStyle(color: Colors.white)),
    );
  }

  Widget _buildKakaoMap(Map<String, dynamic> c) {
    final lat = double.tryParse(c['mapY'] as String? ?? '') ?? 0.0;
    final lng = double.tryParse(c['mapX'] as String? ?? '') ?? 0.0;
    final html = '''
<!DOCTYPE html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests"><style>html,body,#map{margin:0;padding:0;width:100%;height:100%;}</style><script>(function(){const _old=document.write.bind(document);document.write=function(s){_old(s.replace(/http:\\/\\/t1\\.daumcdn\\.net/g,'https://t1.daumcdn.net'));};})();</script><script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7"></script></head><body><div id="map"></div><script>const coord=new kakao.maps.LatLng($lat,$lng);const map=new kakao.maps.Map(document.getElementById('map'),{center:coord,level:3});const marker=new kakao.maps.Marker({position:coord});marker.setMap(map);kakao.maps.event.addListener(map,'idle',()=>map.setCenter(coord));</script></body></html>''';

    return SizedBox(
      height: 200,
      child: InAppWebView(
        initialData: InAppWebViewInitialData(data: html),
        initialOptions: InAppWebViewGroupOptions(
          android: AndroidInAppWebViewOptions(
            mixedContentMode:
                AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          ),
          ios: IOSInAppWebViewOptions(allowsInlineMediaPlayback: true),
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
