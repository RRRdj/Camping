/// lib/screens/camping_info_screen.dart
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  final TextEditingController _txtCtr = TextEditingController();
  int _rating = 5;
  String? _contentId;
  String? _userNickname;

  @override
  void initState() {
    super.initState();
    _bookmarked = widget.isBookmarked;
    _campFuture = _repo.getCamp(widget.campName);
    _imagesFuture = _campFuture.then((doc) async {
      final data = doc.data()!;
      final cid = data['contentId']?.toString() ?? '';
      _contentId = cid;
      final firstUrl = data['firstImageUrl'] as String?;
      return _service.fetchImages(cid, firstUrl);
    });
    _loadUserNickname();
  }

  Future<void> _loadUserNickname() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final nick = await _repo.getUserNickname(user.uid);
    setState(() => _userNickname = nick);
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
            final c = snap.data!.data()!;
            final isAvail = widget.available > 0;
            final amenities =
                (c['amenities'] as List<dynamic>?)?.cast<String>() ?? [];
            _contentId ??= c['contentId']?.toString() ?? '';

            return CustomScrollView(
              slivers: [
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
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 12),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 제목 / 공유 / 즐겨찾기
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c['name'] as String,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.teal),
                            onPressed: () => _showMsg('공유 기능 준비중'),
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
                              widget.onToggleBookmark(widget.campName);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 날짜 + 예약 상태
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
                      // 예약/정보/알림 버튼
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
                                        camp: {'name': c['name']},
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
                                      'campName': c['name'],
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
                      const SizedBox(height: 12),
                      // 예약하기 버튼
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
                      InfoRow(
                        label: '주소',
                        value: c['addr1'] ?? '정보없음',
                        icon: Icons.location_on,
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 8),
                      _buildKakaoMap(c),
                      const SizedBox(height: 12),
                      InfoRow(
                        label: '전화번호',
                        value: c['tel'] ?? '정보없음',
                        icon: Icons.phone,
                        color: Colors.teal,
                        onTap: () => _launchDialer(c['tel'] ?? ''),
                      ),
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
                        style: TextStyle(
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
<!DOCTYPE html><html><head><meta charset=\"utf-8\"><meta http-equiv=\"Content-Security-Policy\" content=\"upgrade-insecure-requests\"><style>html,body,#map{margin:0;padding:0;width:100%;height:100%;}</style><script>(function(){const _old=document.write.bind(document);document.write=function(s){_old(s.replace(/http:\\/\\/t1\\.daumcdn\\.net/g,'https://t1.daumcdn.net'));};})();</script><script src=\"https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7\"></script></head><body><div id=\"map\"></div><script>const coord=new kakao.maps.LatLng($lat,$lng);const map=new kakao.maps.Map(document.getElementById('map'),{center:coord,level:3});const marker=new kakao.maps.Marker({position:coord});marker.setMap(map);kakao.maps.event.addListener(map,'idle',function(){map.setCenter(coord);});</script></body></html>''';

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
