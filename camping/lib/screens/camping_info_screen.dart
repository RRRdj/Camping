// lib/screens/camping_info_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camping/screens/camping_reservation_screen.dart';
import 'package:camping/screens/reservation_info_screen.dart';

class CampingInfoScreen extends StatefulWidget {
  final String campName;
  final int available;
  final int total;
  final bool isBookmarked;
  final void Function(String campName) onToggleBookmark;

  const CampingInfoScreen({
    Key? key,
    required this.campName,
    required this.available,
    required this.total,
    required this.isBookmarked,
    required this.onToggleBookmark,
  }) : super(key: key);

  @override
  State<CampingInfoScreen> createState() => _CampingInfoScreenState();
}

class _CampingInfoScreenState extends State<CampingInfoScreen> {
  static const _serviceKey =
      'aL18yks/TuI52tnTlLaQJMx9YCVO0R+vqXjDZBmBe3ST78itxBjo6ZKJIvlWWSh2tTqkWFpbpELlGrCuKFlUaw==';

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
    _campFuture = FirebaseFirestore.instance
        .collection('campgrounds')
        .doc(widget.campName)
        .get();
    _imagesFuture = _campFuture.then((doc) {
      final data = doc.data()!;
      final cid = data['contentId']?.toString() ?? '';
      _contentId = cid;
      final firstUrl = data['firstImageUrl'] as String?;
      return _fetchImages(cid, firstUrl);
    });
    _loadUserNickname();
  }

  Future<void> _loadUserNickname() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    setState(() {
      _userNickname = doc.data()?['nickname'] as String?;
    });
  }

  Future<List<String>> _fetchImages(String contentId, String? firstUrl) async {
    if (contentId.isEmpty) return [];
    final uri = Uri.parse('https://apis.data.go.kr/B551011/GoCamping/imageList')
        .replace(queryParameters: {
      'serviceKey': _serviceKey,
      'contentId': contentId,
      'MobileOS': 'AND',
      'MobileApp': 'camping',
      'numOfRows': '20',
      'pageNo': '1',
      '_type': 'XML',
    });
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return [];
    final doc = XmlDocument.parse(utf8.decode(resp.bodyBytes));
    final urls = doc
        .findAllElements('imageUrl')
        .map((e) => e.text.trim())
        .where((u) => u.isNotEmpty)
        .toList();
    if (firstUrl != null && firstUrl.isNotEmpty && !urls.contains(firstUrl)) {
      urls.insert(0, firstUrl);
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
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
              return const Center(
                  child: Text('캠핑장 정보를 불러올 수 없습니다.'));
            }

            final c = snap.data!.data()!;
            final dateLabel = DateFormat('MM월 dd일')
                .format(DateTime.now().add(const Duration(days: 1)));
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
                          itemBuilder: (_, i) =>
                              Image.network(imgs[i], fit: BoxFit.cover),
                        );
                      },
                    ),
                  ),
                ),
                SliverPadding(
                  padding:
                  EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 12),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 제목 / 공유 / 즐겨찾기
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c['name'] as String,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.teal),
                            onPressed: () => _showMsg('공유 기능 준비중'),
                          ),
                          IconButton(
                            icon: Icon(
                              _bookmarked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
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
                      // 예약 현황 / 예약정보
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(
                                Icons.calendar_today_outlined),
                            label: const Text('예약 현황'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CampingReservationScreen(camp: {
                                        'name': c['name']
                                      }),
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
                                  builder: (_) =>
                                  const ReservationInfoScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 예약하기 버튼
                      ElevatedButton(
                        onPressed: () async {
                          final type = c['type'];
                          String? url;
                          if (type == '국립') {
                            url =
                            'https://reservation.knps.or.kr/reservation/searchSimpleCampReservation.do';
                          } else {
                            url = c['resveUrl'];
                          }
                          if (url == null || url.isEmpty) {
                            _showMsg('예약 페이지가 없습니다.');
                            return;
                          }
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } else {
                            _showMsg('페이지를 열 수 없습니다.');
                          }
                        },
                        child: const Text('예약하기'),
                      ),
                      const Divider(height: 32),

                      // 주소
                      _InfoRow(
                        label: '주소',
                        value: c['addr1'] ?? '정보없음',
                        icon: Icons.location_on,
                        color: Colors.teal,
                      ),

                      // ─── Kakao Map InAppWebView ───
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: Builder(builder: (ctx) {
                          final lat = double.tryParse(
                              c['mapY'] as String? ?? '') ??
                              0.0;
                          final lng = double.tryParse(
                              c['mapX'] as String? ?? '') ??
                              0.0;

                          // document.write 훅킹 + HTTPS 업그레이드 + Kakao SDK 로드
                          final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
  <style>
    html, body, #map {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
    }
  </style>
  <script>
    (function(){
      const _old = document.write.bind(document);
      document.write = function(s){
        _old(s.replace(/http:\\/\\/t1\\.daumcdn\\.net/g, 'https://t1.daumcdn.net'));
      }
    })();
  </script>
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    const coord = new kakao.maps.LatLng($lat, $lng);
    const map = new kakao.maps.Map(
      document.getElementById('map'),
      { center: coord, level: 3 }
    );
    const imageSrc = 'https://t1.daumcdn.net/localimg/localimages/07/mapapidoc/marker_red.png';
    const imageSize = new kakao.maps.Size(24,35);
    const imageOption = { offset: new kakao.maps.Point(12,35) };
    const markerImage = new kakao.maps.MarkerImage(imageSrc, imageSize, imageOption);
    const marker = new kakao.maps.Marker({
      position: coord,
      image: markerImage
    });
    marker.setMap(map);

    // ✅ 지도 렌더링이 끝난 뒤에 다시 중앙으로
    kakao.maps.event.addListener(map, 'idle', function() {
      map.setCenter(coord);
    });
  </script>
</body>
</html>

''';

                          return InAppWebView(
                            initialData: InAppWebViewInitialData(data: html),
                            initialOptions: InAppWebViewGroupOptions(
                              android: AndroidInAppWebViewOptions(
                                mixedContentMode: AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,

                              ),
                              ios: IOSInAppWebViewOptions(
                                allowsInlineMediaPlayback: true,
                              ),
                            ),
                            onWebViewCreated: (controller) {
                              // 필요하다면 추가 로직
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      // ─── Map 끝 ───

                      _InfoRow(
                        label: '전화번호',
                        value: c['tel'] ?? '정보없음',
                        icon: Icons.phone,
                        color: Colors.teal,
                        onTap: () => _launchDialer(c['tel'] ?? ''),
                      ),
                      _InfoRow(
                        label: '캠핑장 유형',
                        value: c['inDuty'] ?? '정보없음',
                        icon: Icons.event_note,
                        color: Colors.blueGrey,
                      ),
                      if ((c['lctCl'] ?? '').isNotEmpty)
                        _InfoRow(
                          label: '환경',
                          value: c['lctCl']!,
                          icon: Icons.nature,
                          color: Colors.brown,
                        ),
                      const Divider(height: 32),
                      _AmenitySection(amenities: amenities),
                      const Divider(height: 32),
                      const Text('상세 정보',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                          '이곳에 해당 야영장의 시설 설명, 이용 요금, 부가 서비스 등을 표시할 수 있습니다.'),
                      const Divider(height: 32),
                      _ReviewForm(
                        txtCtr: _txtCtr,
                        rating: _rating,
                        onRating: (v) => setState(() => _rating = v),
                        onSubmit: _submitReview,
                        userNickname: _userNickname,
                      ),
                      const Divider(height: 32),
                      _ReviewList(contentId: _contentId ?? ''),
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

  Future<void> _submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMsg('로그인 후 이용 가능합니다.');
      return;
    }
    if (_txtCtr.text.trim().isEmpty) {
      _showMsg('내용을 입력하세요.');
      return;
    }
    if ((_contentId ?? '').isEmpty) {
      _showMsg('캠핑장 정보 오류');
      return;
    }
    if ((_userNickname ?? '').isEmpty) {
      _showMsg('닉네임 정보가 없습니다.');
      return;
    }

    final now = DateTime.now();
    final reviewData = {
      'userId': user.uid,
      'nickname': _userNickname,
      'email': user.email ?? '',
      'rating': _rating,
      'content': _txtCtr.text.trim(),
      'date': now,
    };
    await FirebaseFirestore.instance
        .collection('campground_reviews')
        .doc(_contentId)
        .collection('reviews')
        .add(reviewData);

    final userReviewData = {
      'contentId': _contentId,
      'campName': widget.campName,
      'rating': _rating,
      'content': _txtCtr.text.trim(),
      'date': now,
    };
    await FirebaseFirestore.instance
        .collection('user_reviews')
        .doc(user.uid)
        .collection('reviews')
        .add(userReviewData);

    _txtCtr.clear();
    setState(() => _rating = 5);
    _showMsg('리뷰가 등록되었습니다.');
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// --- 정보 행 표시용 위젯 ---
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text('$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Expanded(child: Text(value)),
          ],
        ),
      ),
    );
  }
}

// --- 편의시설 표시용 위젯 ---
class _AmenitySection extends StatelessWidget {
  final List<String> amenities;
  const _AmenitySection({required this.amenities});

  @override
  Widget build(BuildContext context) {
    if (amenities.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('편의시설',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: amenities.map((e) => Chip(label: Text(e))).toList(),
        ),
      ],
    );
  }
}

// --- 리뷰 작성 폼 위젯 ---
class _ReviewForm extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRating;
  final TextEditingController txtCtr;
  final VoidCallback onSubmit;
  final String? userNickname;

  const _ReviewForm({
    required this.rating,
    required this.onRating,
    required this.txtCtr,
    required this.onSubmit,
    required this.userNickname,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('리뷰 작성',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (userNickname != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('작성자: $userNickname',
              style: const TextStyle(color: Colors.grey)),
        ),
      Row(
        children: [
          const Text('평점:'), const SizedBox(width: 8),
          DropdownButton<int>(
            value: rating,
            items: List.generate(
                5,
                    (i) => DropdownMenuItem(
                    value: i + 1, child: Text('${i + 1}'))),
            onChanged: (v) {
              if (v != null) onRating(v);
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: txtCtr,
        minLines: 3,
        maxLines: 5,
        decoration: InputDecoration(
          labelText: '내용',
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton(onPressed: onSubmit, child: const Text('등록')),
      ),
    ],
  );
}

// --- 리뷰 리스트 표시 위젯 ---
class _ReviewList extends StatelessWidget {
  final String contentId;
  const _ReviewList({required this.contentId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (contentId.isEmpty) {
      return const Text('리뷰를 불러올 수 없습니다.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text('아직 등록된 리뷰가 없습니다.');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: docs.map((doc) {
            final data = doc.data()! as Map<String, dynamic>;
            final reviewerId = data['userId'] ?? '';
            final reviewId = doc.id;
            final nick = data['nickname'] ?? '익명';
            final date = data['date'] != null
                ? (data['date'] as Timestamp).toDate().toString().substring(0, 10)
                : '';
            final rating = data['rating'] ?? 5;
            final content = data['content'] ?? '';

            List<Widget> actionButtons = [];
            if (currentUser != null && reviewerId == currentUser.uid) {
              actionButtons.addAll([
                IconButton(
                  icon:
                  const Icon(Icons.edit, size: 18, color: Colors.teal),
                  tooltip: '수정',
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.delete,
                      size: 18, color: Colors.red),
                  tooltip: '삭제',
                  onPressed: () {},
                ),
              ]);
            } else if (currentUser != null) {
              actionButtons.add(
                IconButton(
                  icon: const Icon(Icons.flag,
                      size: 18, color: Colors.redAccent),
                  tooltip: '신고',
                  onPressed: () => _showReportDialog(
                      context, reviewId, reviewerId),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(nick,
                        style:
                        const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(date,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                    const Spacer(),
                    ...actionButtons
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
                const SizedBox(height: 4),
                Text(content),
                const Divider(),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _showReportDialog(
      BuildContext context, String reviewId, String reportedUserId) async {
    final reporter = FirebaseAuth.instance.currentUser;
    if (reporter == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인 후 이용해주세요.')));
      return;
    }

    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('신고 사유 입력'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration:
          const InputDecoration(hintText: '신고 사유를 입력하세요'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
              child: const Text('확인')),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('신고 확인'),
        content: const Text('이 리뷰를 신고하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('신고')),
        ],
      ),
    );
    if (confirm != true) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(reporter.uid)
        .get();
    final reporterNickname = userDoc.data()?['nickname'] as String? ?? '';

    final batch = FirebaseFirestore.instance.batch();
    final reportRef = FirebaseFirestore.instance.collection('review_reports').doc();
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

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
  }
}
