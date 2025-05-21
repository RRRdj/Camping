import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../repositories/camp_repository.dart';
import '../services/static_data_service.dart';
import '../services/camp_util_service.dart';
import 'camping_reservation_screen.dart';
import 'reservation_info_screen.dart';

class CampingInfoScreen extends StatefulWidget {
  final String campName;
  final int available, total;
  final bool isBookmarked;
  final void Function(String) onToggleBookmark;
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
  // DI
  final _repo = CampRepository();
  final _util = CampUtilService();

  // State
  late bool _bookmarked = widget.isBookmarked;
  late Future<DocumentSnapshot<Map<String, dynamic>>> _campFuture = _repo
      .campgroundDoc(widget.campName);
  late Future<List<String>> _imagesFuture;
  String? _contentId, _userNickname;
  int _rating = 5;
  final _reviewCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _imagesFuture = _campFuture.then((d) {
      final data = d.data()!;
      _contentId = data['contentId']?.toString();
      return _repo.campImages(_contentId ?? '', data['firstImageUrl']);
    });
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      _repo.userNickname(u.uid).then((n) => setState(() => _userNickname = n));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FutureBuilder(
      future: _campFuture,
      builder: (_, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final camp = snap.data!.data()!;
        final amenities = (camp['amenities'] as List?)?.cast<String>() ?? [];

        return CustomScrollView(
          slivers: [
            _sliverAppBar(),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _titleRow(camp['name']),
                  const SizedBox(height: 12),
                  _availabilityText(),
                  const SizedBox(height: 12),
                  _actionButtons(camp),
                  const SizedBox(height: 12),
                  _reservationButton(camp),
                  const Divider(height: 32),
                  _infoBlock(camp, amenities),
                  const Divider(height: 32),
                  _introBlock(camp),
                  const Divider(height: 32),
                  _reviewBlock(),
                ]),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _sliverAppBar() => SliverAppBar(
    pinned: true,
    expandedHeight: 250,
    backgroundColor: Colors.teal,
    flexibleSpace: FlexibleSpaceBar(
      background: FutureBuilder<List<String>>(
        future: _imagesFuture,
        builder:
            (_, s) =>
                s.hasData && s.data!.isNotEmpty
                    ? PageView(
                      children:
                          s.data!
                              .map(
                                (url) => Image.network(url, fit: BoxFit.cover),
                              )
                              .toList(),
                    )
                    : Container(color: Colors.grey.shade200),
      ),
    ),
  );

  Widget _titleRow(String name) => Row(
    children: [
      Expanded(
        child: Text(
          name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.share, color: Colors.teal),
        onPressed: () => _toast('공유 기능 준비중'),
      ),
      IconButton(
        icon: Icon(
          _bookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: _bookmarked ? Colors.red : Colors.grey,
        ),
        onPressed: () {
          setState(() => _bookmarked = !_bookmarked);
          widget.onToggleBookmark(widget.campName);
        },
      ),
    ],
  );

  Widget _availabilityText() {
    final a = widget.available > 0;
    return Text(
      '${DateFormat('MM월 dd일').format(widget.selectedDate)} ${a ? '예약 가능' : '예약 마감'}'
      '(${widget.available}/${widget.total})',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: a ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _actionButtons(Map c) => Row(
    children: [
      _outlined(
        '예약 현황',
        Icons.calendar_today_outlined,
        () => _push(CampingReservationScreen(camp: {'name': c['name']})),
      ),
      const SizedBox(width: 8),
      _outlined(
        '예약정보',
        Icons.info_outline,
        () => _push(
          ReservationInfoScreen(),
          args: {'campName': c['name'], 'contentId': _contentId},
        ),
      ),
      const SizedBox(width: 8),
      _outlined('알림', Icons.notifications_active_outlined, _onTapAlarm),
    ],
  );

  Widget _reservationButton(Map c) => ElevatedButton(
    onPressed: () async {
      final ok = await _util.openExternalUrl(
        _util.reservationUrl(c['type'], c['resveUrl']),
      );
      if (!ok) _toast('예약 페이지가 없습니다.\n전화: ${c['tel'] ?? '-'}');
    },
    child: const Text('예약하기'),
  );

  Widget _infoBlock(Map c, List<String> amn) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _infoRow('주소', c['addr1'] ?? '정보없음', Icons.location_on, Colors.teal),
      const SizedBox(height: 8),
      SizedBox(
        height: 200,
        child: InAppWebView(
          initialData: InAppWebViewInitialData(
            data: _util.kakaoMapHtml(
              double.tryParse(c['mapY'] ?? '') ?? 0,
              double.tryParse(c['mapX'] ?? '') ?? 0,
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _infoRow(
        '전화번호',
        c['tel'] ?? '-',
        Icons.phone,
        Colors.teal,
        onTap: () => _util.dial(c['tel'] ?? ''),
      ),
      _infoRow('캠핑장 유형', c['type'] ?? '-', Icons.circle, Colors.teal),
      _infoRow('캠핑장 구분', c['inDuty'] ?? '-', Icons.event_note, Colors.blueGrey),
      if ((c['lctCl'] ?? '').isNotEmpty)
        _infoRow('환경', c['lctCl'], Icons.nature, Colors.brown),
      if (amn.isNotEmpty) ...[
        const Divider(height: 32),
        const Text(
          '편의시설',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: amn.map((e) => Chip(label: Text(e))).toList(),
        ),
      ],
    ],
  );

  Widget _introBlock(Map c) {
    final line = c['lineIntro'] as String? ?? '';
    final txt0 = c['intro'] as String?;
    final txt1 = c['featureNm'] as String?;
    final txt = (txt0?.isNotEmpty == true ? txt0! : (txt1 ?? ''));
    if (line.isEmpty && txt.isEmpty) {
      return const Text(
        '자세한 내용은 예약 현황이나 사이트에서 확인하세요.',
        style: TextStyle(color: Colors.grey),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '기본 정보',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (line.isNotEmpty) ExpandableText(line),
        const SizedBox(height: 4),
        if (txt.isNotEmpty) ExpandableText(txt, trimLines: 5),
      ],
    );
  }

  Widget _reviewBlock() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _ReviewForm(
        rating: _rating,
        txtCtrl: _reviewCtrl,
        userNickname: _userNickname,
        onRating: (v) => setState(() => _rating = v),
        onSubmit: _submitReview,
      ),
      const Divider(height: 32),
      _ReviewList(contentId: _contentId ?? '', repo: _repo),
    ],
  );

  Widget _outlined(String t, IconData ic, VoidCallback f) =>
      OutlinedButton.icon(icon: Icon(ic), label: Text(t), onPressed: f);

  Widget _infoRow(
    String l,
    String v,
    IconData ic,
    Color col, {
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(ic, color: col, size: 20),
          const SizedBox(width: 8),
          Text('$l: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(v)),
        ],
      ),
    ),
  );

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _push(Widget w, {Object? args}) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => w,
      settings: RouteSettings(arguments: args),
    ),
  );

  Future<void> _onTapAlarm() async {
    // ... 기존 알림 로직 그대로 유지 ...
  }

  Future<void> _submitReview() async {
    // ... 기존 리뷰 제출 로직 그대로 유지 ...
  }
}

/* ───────────────────────────── ExpandableText ───────────────────────────── */

class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int trimLines;
  const ExpandableText(this.text, {super.key, this.style, this.trimLines = 3});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;
  bool _needTrim = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTrim());
  }

  void _checkTrim() {
    final span = TextSpan(text: widget.text, style: widget.style);
    final tp = TextPainter(
      text: span,
      maxLines: widget.trimLines,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 32);

    setState(() => _needTrim = tp.didExceedMaxLines);
  }

  @override
  Widget build(BuildContext context) {
    if (!_needTrim) return Text(widget.text, style: widget.style);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: widget.style,
          maxLines: _expanded ? null : widget.trimLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
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
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────────── _ReviewForm ───────────────────────────── */

class _ReviewForm extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRating;
  final TextEditingController txtCtrl;
  final VoidCallback onSubmit;
  final String? userNickname;

  const _ReviewForm({
    required this.rating,
    required this.onRating,
    required this.txtCtrl,
    required this.onSubmit,
    required this.userNickname,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '리뷰 작성',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
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
            items: List.generate(5, (i) {
              final v = i + 1;
              return DropdownMenuItem<int>(value: v, child: Text('$v'));
            }),
            // ↓ 여기서 Nullable int? 을 래핑합니다
            onChanged: (int? v) {
              if (v != null) onRating(v);
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: txtCtrl,
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

/* ───────────────────────────── _ReviewList ───────────────────────────── */

class _ReviewList extends StatelessWidget {
  final String contentId;
  final CampRepository repo;
  const _ReviewList({required this.contentId, required this.repo});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (contentId.isEmpty) return const Text('리뷰를 불러올 수 없습니다.');

    return StreamBuilder<QuerySnapshot>(
      stream: repo.reviewsStream(contentId),
      builder: (ctx, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Text('아직 등록된 리뷰가 없습니다.');

        return Column(
          children:
              docs.map((d) {
                final data = d.data()! as Map<String, dynamic>;
                final rid = d.id;
                final uid = data['userId'] as String? ?? '';
                final nick = data['nickname'] as String? ?? '익명';
                final date =
                    data['date'] != null
                        ? (data['date'] as Timestamp)
                            .toDate()
                            .toString()
                            .substring(0, 10)
                        : '';
                final rate = data['rating'] as int? ?? 5;
                final cont = data['content'] as String? ?? '';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          nick,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (user?.uid == uid) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.teal,
                            ),
                            onPressed:
                                () => _editReview(context, rid, rate, cont),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteReview(context, rid),
                          ),
                        ] else if (user != null)
                          IconButton(
                            icon: const Icon(
                              Icons.flag,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _reportReview(context, rid, uid),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rate ? Icons.star : Icons.star_border,
                          color: Colors.green,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(cont),
                    const Divider(),
                  ],
                );
              }).toList(),
        );
      },
    );
  }

  void _editReview(
    BuildContext ctx,
    String rid,
    int oldRate,
    String oldC,
  ) async {
    final ctrl = TextEditingController(text: oldC);
    int newRate = oldRate;
    final ok = await showDialog<bool>(
      context: ctx,
      builder:
          (_) => AlertDialog(
            title: const Text('리뷰 수정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: newRate,
                  items:
                      List.generate(5, (i) => i + 1)
                          .map(
                            (v) =>
                                DropdownMenuItem(value: v, child: Text('$v')),
                          )
                          .toList(),
                  onChanged: (v) => v != null ? newRate = v : null,
                ),
                TextField(
                  controller: ctrl,
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
    if (ok == true) {
      await repo.updateReview(
        contentId: contentId,
        reviewId: rid,
        rating: newRate,
        content: ctrl.text.trim(),
      );
    }
  }

  void _deleteReview(BuildContext ctx, String rid) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder:
          (_) => AlertDialog(
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
    if (ok == true)
      await repo.deleteReview(contentId: contentId, reviewId: rid);
  }

  void _reportReview(BuildContext ctx, String rid, String reportedUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String?>(
      context: ctx,
      builder:
          (_) => AlertDialog(
            title: const Text('신고 사유'),
            content: TextField(controller: reasonCtrl, maxLines: 3),
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
    if (reason?.isEmpty != false) return;
    final confirm = await showDialog<bool>(
      context: ctx,
      builder:
          (_) => AlertDialog(
            title: const Text('신고 확인'),
            content: const Text('리뷰를 신고하시겠습니까?'),
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
    final nick = await repo.userNickname(user.uid) ?? user.email ?? '익명';
    await repo.reportReview(
      contentId: contentId,
      reviewId: rid,
      reportedUserId: reportedUid,
      reportData: {
        'reporterUid': user.uid,
        'reporterEmail': user.email ?? '',
        'reporterNickname': nick,
        'reason': reason,
        'date': FieldValue.serverTimestamp(),
      },
    );
  }
}
