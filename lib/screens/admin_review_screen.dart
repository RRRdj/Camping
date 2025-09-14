import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  // ----------------- Firestore refs -----------------
  CollectionReference<Map<String, dynamic>> get _reportColl =>
      FirebaseFirestore.instance.collection('review_reports');

  CollectionReference<Map<String, dynamic>> get _campColl =>
      FirebaseFirestore.instance.collection('campgrounds');

  CollectionReference<Map<String, dynamic>> _campReviewColl(String contentId) =>
      FirebaseFirestore.instance
          .collection('campground_reviews')
          .doc(contentId)
          .collection('reviews');

  CollectionReference<Map<String, dynamic>> _userReviewColl(String userId) =>
      FirebaseFirestore.instance
          .collection('user_reviews')
          .doc(userId)
          .collection('reviews');

  // ---- fetch futures cache (중복 쿼리 방지) ----
  static final Map<String, Future<QuerySnapshot<Map<String, dynamic>>>>
  _campByContentIdFuture = {};
  static final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
  _reviewDocFuture = {};

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchCampByContentId(
      String contentId,
      ) {
    return _campByContentIdFuture.putIfAbsent(
      contentId,
          () => _campColl.where('contentId', isEqualTo: contentId).limit(1).get(),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchReviewDoc(
      String contentId,
      String reviewId,
      ) {
    final key = '$contentId::$reviewId';
    return _reviewDocFuture.putIfAbsent(
      key,
          () => _campReviewColl(contentId).doc(reviewId).get(),
    );
  }

  // --------------- 검색 상태/컨트롤 ---------------
  final TextEditingController _q = TextEditingController();
  Timer? _debounce;

  // 검색 타입: camp(야영장명), reporter(신고자 닉/이메일), author(작성자 닉네임)
  String _mode = 'camp';
  String _keyword = '';

  // 조인 데이터 캐시(검색용)
  final Map<String, String> _campNameCache = {}; // contentId -> camp name
  final Map<String, String> _authorNameCache = {}; // contentId::reviewId -> nickname

  @override
  void initState() {
    super.initState();
    _q.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.removeListener(_onChanged);
    _q.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (_keyword != _q.text.trim()) {
        setState(() => _keyword = _q.text.trim());
      }
    });
  }

  // 캠프/작성자 검색이면 미리 조인 값 확보
  Future<void> _ensureJoinValues(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> reports,
      ) async {
    if (_mode == 'camp') {
      final ids = <String>{};
      for (final r in reports) {
        final cid = (r.data()['contentId'] as String?) ?? '';
        if (cid.isNotEmpty && !_campNameCache.containsKey(cid)) ids.add(cid);
      }
      await Future.wait(ids.map((cid) async {
        final snap = await _fetchCampByContentId(cid);
        final name = snap.docs.isNotEmpty
            ? (snap.docs.first.data()['name'] as String? ?? '')
            : '';
        _campNameCache[cid] = name;
      }));
    } else if (_mode == 'author') {
      final keys = <String>{};
      for (final r in reports) {
        final m = r.data();
        final cid = (m['contentId'] as String?) ?? '';
        final rid = (m['reviewId'] as String?) ?? '';
        if (cid.isEmpty || rid.isEmpty) continue;
        final key = '$cid::$rid';
        if (!_authorNameCache.containsKey(key)) keys.add(key);
      }
      await Future.wait(keys.map((k) async {
        final parts = k.split('::');
        final doc = await _fetchReviewDoc(parts[0], parts[1]);
        final nick = (doc.data()?['nickname'] as String?) ?? '';
        _authorNameCache[k] = nick;
      }));
    }
  }

  // ----------------------- UI -----------------------
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('신고된 후기 관리')),
      body: SafeArea(
        child: Column(
          children: [
            // 검색 바
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _q,
                      decoration: InputDecoration(
                        hintText: _mode == 'camp'
                            ? '야영장명 검색'
                            : _mode == 'reporter'
                            ? '신고자(닉/이메일) 검색'
                            : '작성자 닉네임 검색',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _mode,
                    items: const [
                      DropdownMenuItem(value: 'camp', child: Text('야영장')),
                      DropdownMenuItem(value: 'reporter', child: Text('신고자')),
                      DropdownMenuItem(value: 'author', child: Text('작성자')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _mode = v;
                        _keyword = '';
                        _q.text = '';
                      });
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 리스트
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                _reportColl.orderBy('date', descending: true).snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('불러오기 실패: ${snap.error}'));
                  }
                  final reports = snap.data?.docs ?? [];
                  if (reports.isEmpty) {
                    return const Center(child: Text('신고된 후기가 없습니다.'));
                  }

                  // 캠프/작성자 검색이면 조인값 로드 보장
                  return FutureBuilder<void>(
                    future: _ensureJoinValues(reports),
                    builder: (context, _) {
                      // 필터링
                      final filtered = reports.where((r) {
                        final m = r.data();
                        if (_mode == 'reporter') {
                          final nick =
                          (m['reporterNickname'] as String? ?? '')
                              .toLowerCase();
                          final email =
                          (m['reporterEmail'] as String? ?? '')
                              .toLowerCase();
                          final q = _keyword.toLowerCase();
                          return _keyword.isEmpty ||
                              nick.contains(q) ||
                              email.contains(q);
                        } else if (_mode == 'camp') {
                          final cid = (m['contentId'] as String?) ?? '';
                          final name =
                          (_campNameCache[cid] ?? '').toLowerCase();
                          final q = _keyword.toLowerCase();
                          return _keyword.isEmpty || name.contains(q);
                        } else if (_mode == 'author') {
                          final cid = (m['contentId'] as String?) ?? '';
                          final rid = (m['reviewId'] as String?) ?? '';
                          final key = '$cid::$rid';
                          final nick =
                          (_authorNameCache[key] ?? '').toLowerCase();
                          final q = _keyword.toLowerCase();
                          return _keyword.isEmpty || nick.contains(q);
                        }
                        return true;
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Center(child: Text('검색 결과가 없습니다.'));
                      }

                      return ListView.separated(
                        padding: EdgeInsets.only(bottom: bottomPad + 12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 4),
                        itemBuilder: (context, idx) {
                          final reportDoc = filtered[idx];
                          final report = reportDoc.data();

                          final reporterNick =
                              (report['reporterNickname'] as String?) ?? '익명';
                          final reporterEmail =
                              (report['reporterEmail'] as String?) ?? '';
                          final reason =
                              (report['reason'] as String?) ?? '';
                          final contentId =
                              (report['contentId'] as String?) ?? '';
                          final reviewId =
                              (report['reviewId'] as String?) ?? '';
                          final timestamp =
                          (report['date'] as Timestamp?)?.toDate();

                          final campName =
                              _campNameCache[contentId] ?? '';

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 첫 줄: 리뷰ID + 시간
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '리뷰 ID: $reviewId',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (timestamp != null)
                                        Text(
                                          DateFormat('yyyy-MM-dd HH:mm')
                                              .format(timestamp),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // 야영장만 표시 (오른쪽 작성자 표시는 제거)
                                  Text(
                                    '야영장: ${campName.isEmpty ? '(불러오는 중...)' : campName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),

                                  // 원본 리뷰 내용/사진
                                  FutureBuilder<
                                      DocumentSnapshot<
                                          Map<String, dynamic>>>(
                                    future: (contentId.isEmpty ||
                                        reviewId.isEmpty)
                                        ? Future.value(null)
                                        : _fetchReviewDoc(
                                        contentId, reviewId),
                                    builder: (ctxRev, revSnap) {
                                      if (revSnap.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Text(
                                            '원본 리뷰를 불러오는 중...');
                                      }
                                      final revData =
                                      revSnap.data?.data();
                                      if (revData == null) {
                                        return const Text(
                                            '원본 리뷰가 없습니다.');
                                      }

                                      final origNick =
                                          (revData['nickname']
                                          as String?) ??
                                              '익명';
                                      final origContent =
                                          (revData['content']
                                          as String?) ??
                                              '';
                                      final origDate =
                                      (revData['date']
                                      as Timestamp?)
                                          ?.toDate();
                                      final origUserId =
                                          (revData['userId']
                                          as String?) ??
                                              '';
                                      final imageUrls =
                                          (revData['imageUrls']
                                          as List<dynamic>?)
                                              ?.cast<String>() ??
                                              const <String>[];

                                      return Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text('작성자(원본): $origNick',
                                              style: const TextStyle(
                                                  fontWeight:
                                                  FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          Text(origContent),
                                          const SizedBox(height: 8),
                                          if (imageUrls.isNotEmpty) ...[
                                            const Text('사진:'),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              height: 80,
                                              child: ListView.builder(
                                                scrollDirection:
                                                Axis.horizontal,
                                                itemCount:
                                                imageUrls.length,
                                                itemBuilder: (_, i) =>
                                                    Padding(
                                                      padding:
                                                      const EdgeInsets
                                                          .only(
                                                          right: 8),
                                                      child:
                                                      GestureDetector(
                                                        onTap: () {
                                                          showDialog(
                                                            context:
                                                            context,
                                                            builder: (_) =>
                                                                Dialog(
                                                                  insetPadding:
                                                                  EdgeInsets
                                                                      .zero,
                                                                  child:
                                                                  InteractiveViewer(
                                                                    child: Image
                                                                        .network(
                                                                      imageUrls[
                                                                      i],
                                                                      errorBuilder:
                                                                          (_,
                                                                          __,
                                                                          ___) =>
                                                                      const SizedBox(
                                                                        width:
                                                                        200,
                                                                        height:
                                                                        200,
                                                                        child:
                                                                        Center(
                                                                          child:
                                                                          Text('이미지 로드 실패'),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                          );
                                                        },
                                                        child: ClipRRect(
                                                          borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                              8),
                                                          child:
                                                          Image.network(
                                                            imageUrls[i],
                                                            width: 80,
                                                            height: 80,
                                                            fit: BoxFit
                                                                .cover,
                                                            errorBuilder: (_,
                                                                __,
                                                                ___) =>
                                                                Container(
                                                                  width: 80,
                                                                  height: 80,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade200,
                                                                  alignment:
                                                                  Alignment
                                                                      .center,
                                                                  child:
                                                                  const Icon(
                                                                    Icons
                                                                        .broken_image,
                                                                  ),
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                          Text(
                                            '신고자: $reporterNick '
                                                '(${reporterEmail.isEmpty ? '이메일 미제공' : reporterEmail})',
                                          ),
                                          const SizedBox(height: 4),
                                          Text('사유: $reason'),
                                          const SizedBox(height: 12),
                                          Align(
                                            alignment:
                                            Alignment.centerRight,
                                            child: ElevatedButton(
                                              style: ElevatedButton
                                                  .styleFrom(
                                                backgroundColor:
                                                Colors.redAccent,
                                              ),
                                              onPressed: () async {
                                                final ok =
                                                await showDialog<
                                                    bool>(
                                                  context: context,
                                                  builder: (ctx) =>
                                                      AlertDialog(
                                                        title: const Text(
                                                            '삭제 확인'),
                                                        content: const Text(
                                                            '신고와 연결된 리뷰를 모두 삭제하시겠습니까?'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    ctx,
                                                                    false),
                                                            child:
                                                            const Text(
                                                                '취소'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    ctx,
                                                                    true),
                                                            child:
                                                            const Text(
                                                              '삭제',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                                if (ok != true) return;

                                                try {
                                                  final batch =
                                                  FirebaseFirestore
                                                      .instance
                                                      .batch();
                                                  batch.delete(
                                                      _reportColl.doc(
                                                          reportDoc
                                                              .id));
                                                  if (contentId
                                                      .isNotEmpty &&
                                                      reviewId
                                                          .isNotEmpty) {
                                                    batch.delete(
                                                      _campReviewColl(
                                                          contentId)
                                                          .doc(
                                                          reviewId),
                                                    );
                                                  }
                                                  if (origUserId
                                                      .isNotEmpty &&
                                                      origDate !=
                                                          null &&
                                                      contentId
                                                          .isNotEmpty) {
                                                    final userReviewQuery =
                                                    await _userReviewColl(
                                                        origUserId)
                                                        .where(
                                                        'contentId',
                                                        isEqualTo:
                                                        contentId)
                                                        .where(
                                                        'content',
                                                        isEqualTo:
                                                        origContent)
                                                        .where(
                                                        'date',
                                                        isEqualTo:
                                                        Timestamp.fromDate(
                                                            origDate))
                                                        .get();
                                                    for (final ur
                                                    in userReviewQuery
                                                        .docs) {
                                                      batch.delete(
                                                          ur.reference);
                                                    }
                                                  }
                                                  await batch.commit();
                                                  if (mounted) {
                                                    ScaffoldMessenger
                                                        .of(context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                            '신고 및 리뷰가 삭제되었습니다.'),
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger
                                                        .of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                          content: Text(
                                                              '삭제 실패: $e')),
                                                    );
                                                  }
                                                }
                                              },
                                              child:
                                              const Text('처리 완료'),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
