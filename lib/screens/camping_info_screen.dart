// lib/screens/camping_info_screen.dart

import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:camping/repositories/camp_repository.dart';
import 'package:camping/screens/camping_reservation_screen.dart';
import 'package:camping/screens/reservation_info_screen.dart';
import 'package:camping/services/camp_util_service.dart';

/// 간결성과 모듈화를 위해 UI‐섹션별 위젯으로 분리
class CampingInfoScreen extends StatefulWidget {
  const CampingInfoScreen({
    super.key,
    required this.campName,
    required this.available,
    required this.total,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.selectedDate,
  });

  final String campName;
  final int available, total;
  final bool isBookmarked;
  final void Function(String campName) onToggleBookmark;
  final DateTime selectedDate;

  @override
  State<CampingInfoScreen> createState() => _CampingInfoScreenState();
}

class _CampingInfoScreenState extends State<CampingInfoScreen> {
  final CampRepository _repo = CampRepository();
  final CampUtilService _util = CampUtilService();

  late final Future<DocumentSnapshot<Map<String, dynamic>>> _campFuture;
  late final Future<List<String>> _imagesFuture;
  late bool _bookmarked;

  final _reviewCtr = TextEditingController();
  int _rating = 5;
  String? _contentId, _userNickname;

  @override
  void initState() {
    super.initState();
    _bookmarked = widget.isBookmarked;
    _campFuture = _repo.fetchCamp(widget.campName);
    _imagesFuture = _campFuture.then((d) {
      final data = d.data()!;
      _contentId = data['contentId']?.toString() ?? '';
      return _repo.fetchImages(_contentId!, data['firstImageUrl'] as String?);
    });
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    setState(() => _userNickname = doc.data()?['nickname'] as String?);
  }

  // ————————————————— UI —————————————————
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      top: false,
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _campFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('캠핑장 정보를 불러올 수 없습니다.'));
          }
          final camp = snap.data!.data()!;
          final isAvail = widget.available > 0;
          final dateLabel = DateFormat('MM월 dd일').format(widget.selectedDate);
          _contentId ??= camp['contentId']?.toString() ?? '';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 250,
                backgroundColor: Colors.teal,
                flexibleSpace: FutureBuilder<List<String>>(
                  future: _imagesFuture,
                  builder: (_, imgSnap) => ImageCarousel(imgSnap.data),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).padding.bottom + 12,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _HeaderRow(
                      name: camp['name'] as String,
                      bookmarked: _bookmarked,
                      onShare: () => _showMsg('공유 기능 준비중'),
                      onBookmark: () {
                        setState(() => _bookmarked = !_bookmarked);
                        widget.onToggleBookmark(widget.campName);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$dateLabel ${isAvail ? '예약 가능' : '예약 마감'} (${widget.available}/${widget.total})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isAvail ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ActionButtons(
                      onReservation:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => CampingReservationScreen(
                                    camp: {
                                      'name': camp['name'],
                                      'addr1': camp['addr1'] as String? ?? '',
                                    },
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
                                  'campName': camp['name'],
                                  'contentId': _contentId,
                                },
                              ),
                            ),
                          ),
                      onAlarm: _onTapAlarm,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => _openReservation(camp),
                      child: const Text('예약하기'),
                    ),
                    const Divider(height: 32),
                    InfoRow(
                      label: '주소',
                      value: camp['addr1'] ?? '-',
                      icon: Icons.location_on,
                      onCopy: true,
                    ),
                    SizedBox(
                      height: 200,
                      child: InAppWebView(
                        initialData: InAppWebViewInitialData(
                          data: _util.kakaoMapHtml(
                            double.tryParse(camp['mapY'] ?? '') ?? 0,
                            double.tryParse(camp['mapX'] ?? '') ?? 0,
                          ),
                        ),
                        initialOptions: InAppWebViewGroupOptions(
                          android: AndroidInAppWebViewOptions(
                            mixedContentMode:
                                AndroidMixedContentMode
                                    .MIXED_CONTENT_ALWAYS_ALLOW,
                          ),
                          ios: IOSInAppWebViewOptions(
                            allowsInlineMediaPlayback: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InfoRow(
                      label: '전화번호',
                      value: camp['tel'] ?? '-',
                      icon: Icons.phone,
                      color: Colors.teal,
                      onTap: () => _launchDialer(camp['tel'] ?? ''),
                      onCopy: true,
                    ),
                    const SizedBox(height: 12),
                    AmenitySection(
                      amenities:
                          (camp['amenities'] as List<dynamic>?)
                              ?.cast<String>() ??
                          [],
                    ),
                    const Divider(),
                    _ReviewForm(
                      rating: _rating,
                      userNickname: _userNickname,
                      txtCtr: _reviewCtr,
                      onRating: (v) => setState(() => _rating = v),
                      onSubmit: _submitReview,
                    ),
                    const SizedBox(height: 12),
                    ReviewList(contentId: _contentId ?? ''),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  // ——————————————————— 기능 메서드 ————————————————————
  Future<void> _openReservation(Map<String, dynamic> camp) async {
    final url = _util.reservationUrl(camp['type'] ?? '', camp['resveUrl']);
    if (url.isEmpty) {
      _showMsg('예약 페이지가 없습니다.\n전화로 문의하세요: ${camp['tel'] ?? '-'}');
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showMsg('페이지를 열 수 없습니다.');
    }
  }

  Future<void> _onTapAlarm() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _showMsg('로그인 후 이용해주세요.');

    final alarmsCol = FirebaseFirestore.instance
        .collection('user_alarm_settings')
        .doc(user.uid)
        .collection('alarms');

    if ((await alarmsCol.get()).docs.length >= 5) {
      return _showMsg('알림은 최대 5개까지 설정할 수 있어요.');
    }

    await showDialog(
      context: context,
      builder:
          (_) => const AlertDialog(
            title: Text('알림 설정 안내'),
            content: Text('알림을 받고 싶은 날짜를 선택하세요.'),
          ),
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null) return;

    await alarmsCol.add({
      'campName': widget.campName,
      'contentId': _contentId,
      'date': DateFormat('yyyy-MM-dd').format(picked),
      'isNotified': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _showMsg('${DateFormat('M월 d일').format(picked)} 알림이 설정되었습니다.');
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
    if (user == null) return _showMsg('로그인 후 이용 가능합니다.');
    if (_reviewCtr.text.trim().isEmpty) return _showMsg('내용을 입력하세요.');
    if ((_contentId ?? '').isEmpty) return _showMsg('캠핑장 정보 오류');

    final now = DateTime.now();
    final reviewCol = FirebaseFirestore.instance
        .collection('campground_reviews')
        .doc(_contentId)
        .collection('reviews');
    await reviewCol.add({
      'userId': user.uid,
      'nickname': _userNickname,
      'email': user.email ?? '',
      'rating': _rating,
      'content': _reviewCtr.text.trim(),
      'date': now,
    });

    final userReviewCol = FirebaseFirestore.instance
        .collection('user_reviews')
        .doc(user.uid)
        .collection('reviews');
    await userReviewCol.add({
      'contentId': _contentId,
      'campName': widget.campName,
      'rating': _rating,
      'content': _reviewCtr.text.trim(),
      'date': now,
    });

    _reviewCtr.clear();
    setState(() => _rating = 5);
    _showMsg('리뷰가 등록되었습니다.');
  }

  void _showMsg(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// ———————————————————— Sub-Widgets —————————————————————
class ImageCarousel extends StatelessWidget {
  const ImageCarousel(this.images, {super.key});
  final List<String>? images;

  @override
  Widget build(BuildContext context) {
    if (images == null || images!.isEmpty) {
      return Container(color: Colors.grey.shade200);
    }
    return PageView.builder(
      itemCount: images!.length,
      itemBuilder: (_, i) => Image.network(images![i], fit: BoxFit.cover),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.name,
    required this.bookmarked,
    required this.onShare,
    required this.onBookmark,
  });

  final String name;
  final bool bookmarked;
  final VoidCallback onShare, onBookmark;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      IconButton(icon: const Icon(Icons.share), onPressed: onShare),
      IconButton(
        icon: Icon(
          bookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: bookmarked ? Colors.red : Colors.grey,
        ),
        onPressed: onBookmark,
      ),
    ],
  );
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onReservation,
    required this.onInfo,
    required this.onAlarm,
  });
  final VoidCallback onReservation, onInfo, onAlarm;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _OutlinedIconButton(
        icon: Icons.calendar_today_outlined,
        label: '예약 현황',
        onTap: onReservation,
      ),
      const SizedBox(width: 8),
      _OutlinedIconButton(
        icon: Icons.info_outline,
        label: '예약정보',
        onTap: onInfo,
      ),
      const SizedBox(width: 8),
      _OutlinedIconButton(
        icon: Icons.notifications_active_outlined,
        label: '알림',
        onTap: onAlarm,
      ),
    ],
  );
}

class _OutlinedIconButton extends StatelessWidget {
  const _OutlinedIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: Icon(icon),
    label: Text(label),
    onPressed: onTap,
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
    this.onCopy = false,
  });

  final String label, value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool onCopy;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, color: color ?? Colors.teal, size: 20),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: Text(value)),
        if (onCopy)
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('복사되었습니다.')));
            },
          ),
        if (onTap != null)
          IconButton(
            icon: const Icon(Icons.phone_in_talk, size: 20),
            onPressed: onTap,
          ),
      ],
    ),
  );
}

class AmenitySection extends StatelessWidget {
  const AmenitySection({super.key, required this.amenities});
  final List<String> amenities;
  @override
  Widget build(BuildContext context) {
    if (amenities.isEmpty) {
      return const Text('편의시설 정보가 없습니다.', style: TextStyle(color: Colors.grey));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '편의시설',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: amenities.map((e) => Chip(label: Text(e))).toList(),
        ),
      ],
    );
  }
}

class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.rating,
    required this.onRating,
    required this.txtCtr,
    required this.onSubmit,
    required this.userNickname,
  });
  final int rating;
  final ValueChanged<int> onRating;
  final TextEditingController txtCtr;
  final VoidCallback onSubmit;
  final String? userNickname;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '리뷰 작성',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      if (userNickname != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '작성자: $userNickname',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      Row(
        children: [
          const Text('평점:'),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: rating,
            items: List.generate(
              5,
              (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
            ),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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

class ReviewList extends StatelessWidget {
  const ReviewList({super.key, required this.contentId});
  final String contentId;

  @override
  Widget build(BuildContext context) {
    if (contentId.isEmpty) {
      return const Text('리뷰를 불러올 수 없습니다.');
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('campground_reviews')
              .doc(contentId)
              .collection('reviews')
              .orderBy('date', descending: true)
              .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Text('아직 등록된 리뷰가 없습니다.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              docs.map((d) {
                final data = d.data()! as Map<String, dynamic>;
                final reviewerId = data['userId'] as String? ?? '';
                final rating = data['rating'] as int? ?? 5;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          data['nickname'] ?? '익명',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (data['date'] as Timestamp?)
                                  ?.toDate()
                                  .toString()
                                  .substring(0, 10) ??
                              '',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (currentUser != null &&
                            reviewerId == currentUser.uid)
                          const Icon(Icons.edit, size: 18, color: Colors.teal),
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
                    Text(data['content'] ?? ''),
                    const Divider(),
                  ],
                );
              }).toList(),
        );
      },
    );
  }
}

// ExpandableText는 기존 로직 재사용
class ExpandableText extends StatefulWidget {
  const ExpandableText(this.text, {super.key, this.style, this.trimLines = 3});
  final String text;
  final TextStyle? style;
  final int trimLines;
  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false, _needTrim = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: widget.trimLines,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 32);
    setState(() => _needTrim = tp.didExceedMaxLines);
  }

  @override
  Widget build(BuildContext context) =>
      !_needTrim
          ? Text(widget.text, style: widget.style)
          : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.text,
                style: widget.style,
                maxLines: _expanded ? null : widget.trimLines,
                overflow: _expanded ? null : TextOverflow.ellipsis,
              ),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _expanded ? '간략히' : '더보기',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
}
