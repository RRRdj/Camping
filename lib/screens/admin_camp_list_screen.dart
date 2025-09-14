import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ───────────────────────── 목록 + 검색 ─────────────────────────
class AdminCampListScreen extends StatefulWidget {
  const AdminCampListScreen({Key? key}) : super(key: key);

  @override
  State<AdminCampListScreen> createState() => _AdminCampListScreenState();
}

class _AdminCampListScreenState extends State<AdminCampListScreen> {
  CollectionReference<Map<String, dynamic>> get _coll =>
      FirebaseFirestore.instance.collection('campgrounds');

  // 검색 상태
  final TextEditingController _searchController = TextEditingController();
  String _searchField = 'name'; // name | location | type
  String _keyword = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final next = _searchController.text.trim();
      if (next != _keyword) {
        setState(() => _keyword = next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 시스템 하단 인셋 + FAB가 차지할 공간만큼 리스트에 여유 패딩
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const fabSize = 56.0; // FAB 지름
    const fabMargin = 24.0; // 하단/우측 여백
    final listBottomPadding = bottomInset + fabSize + fabMargin;

    return Scaffold(
      appBar: AppBar(title: const Text('캠핑장 목록 관리')),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // ── 검색 바 ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: () {
                          switch (_searchField) {
                            case 'location':
                              return '위치로 검색 (예:경상북도 구미시)';
                            case 'type':
                              return '유형으로 검색 (예:지자체)';
                            default:
                              return '야영장 이름으로 검색';
                          }
                        }(),
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _searchField,
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('이름')),
                      DropdownMenuItem(value: 'location', child: Text('위치')),
                      DropdownMenuItem(value: 'type', child: Text('유형')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _searchField = v;
                        _keyword = '';
                        _searchController.text = '';
                      });
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── 목록 ────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _coll.orderBy('name', descending: false).snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('로드 실패: ${snap.error}'));
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('등록된 캠핑장이 없습니다.'));
                  }

                  // 클라이언트 사이드 필터링
                  final q = _keyword.toLowerCase();
                  final filtered = docs.where((doc) {
                    final data = doc.data();
                    final value =
                    (data[_searchField] ?? '').toString().toLowerCase();
                    if (q.isEmpty) return true;
                    return value.contains(q);
                  }).toList();

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(0, 8, 0, listBottomPadding),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (ctx2, i) {
                      final doc = filtered[i];
                      final data = doc.data();
                      final name = (data['name'] ?? '') as String;
                      final location = (data['location'] ?? '') as String;
                      final type = (data['type'] ?? '') as String;

                      return Card(
                        margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          key: ValueKey(doc.id),
                          leading: const Icon(Icons.park, color: Colors.teal),

                          // ✅ 긴 이름이 전부 보이도록 줄바꿈 허용(말줄임 제거)
                          title: Text(
                            name,
                            softWrap: true, // 여러 줄 허용
                            // maxLines 기본(null) → 제한 없음
                            // overflow 지정 제거 → 말줄임표 없음
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          // 위치 · 유형은 1줄 유지
                          subtitle: Text(
                            '$location • $type',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // title이 2줄 이상일 수도 있으니 높이 확보
                          isThreeLine: true,

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '수정',
                                icon: const Icon(Icons.edit, color: Colors.grey),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminCampFormScreen(
                                        docId: doc.id,
                                        existingData: data,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: '삭제',
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx3) => AlertDialog(
                                      title: const Text('삭제 확인'),
                                      content: Text('“$name” 항목을 삭제하시겠습니까?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx3, false),
                                          child: const Text('취소'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx3, true),
                                          child: const Text(
                                            '삭제',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    try {
                                      await _coll.doc(doc.id).delete();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('삭제되었습니다.'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('삭제 실패: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: FloatingActionButton(
          tooltip: '신규 캠핑장 추가',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminCampFormScreen()),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// ───────────────────────── 등록/수정 폼 (mapX/mapY 포함) ─────────────────────────
class AdminCampFormScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existingData;

  const AdminCampFormScreen({Key? key, this.docId, this.existingData})
      : super(key: key);

  @override
  State<AdminCampFormScreen> createState() => _AdminCampFormScreenState();
}

class _AdminCampFormScreenState extends State<AdminCampFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // 필드 스펙
  late final _FieldSpec _name;
  late final _FieldSpec _location;
  late final _FieldSpec _type;
  late final _FieldSpec _mapX; // 경도
  late final _FieldSpec _mapY; // 위도
  late final _FieldSpec _contentId;
  late final _FieldSpec _firstImageUrl;
  late final _FieldSpec _inDuty;
  late final _FieldSpec _lctCl;
  late final _FieldSpec _lineIntro;
  late final _FieldSpec _intro;
  late final _FieldSpec _featureNm;
  late final _FieldSpec _reservationWarning;
  late final _FieldSpec _resveUrl;
  late final _FieldSpec _tel;

  List<_FieldSpec> get _fields => [
    _name,
    _location,
    _type,
    _mapX,
    _mapY,
    _contentId,
    _firstImageUrl,
    _inDuty,
    _lctCl,
    _lineIntro,
    _intro,
    _featureNm,
    _reservationWarning,
    _resveUrl,
    _tel,
  ];

  CollectionReference<Map<String, dynamic>> get _coll =>
      FirebaseFirestore.instance.collection('campgrounds');

  @override
  void initState() {
    super.initState();
    final d = widget.existingData ?? const <String, dynamic>{};
    String _t(String key) => (d[key] ?? '').toString();

    _name = _FieldSpec('이름', TextEditingController(text: _t('name')));
    _location = _FieldSpec('위치', TextEditingController(text: _t('location')));
    _type = _FieldSpec('유형', TextEditingController(text: _t('type')));

    _mapX = _FieldSpec(
      '경도 (mapX, 예: 128.3446)',
      TextEditingController(text: _t('mapX')),
      keyboardType:
      const TextInputType.numberWithOptions(decimal: true, signed: true),
      validator: (v) => _doubleInRange(v, -180, 180, '경도(mapX)'),
    );
    _mapY = _FieldSpec(
      '위도 (mapY, 예: 36.1190)',
      TextEditingController(text: _t('mapY')),
      keyboardType:
      const TextInputType.numberWithOptions(decimal: true, signed: true),
      validator: (v) => _doubleInRange(v, -90, 90, '위도(mapY)'),
    );

    _contentId =
        _FieldSpec('콘텐츠 ID', TextEditingController(text: _t('contentId')));
    _firstImageUrl = _FieldSpec(
      '이미지 URL',
      TextEditingController(text: _t('firstImageUrl')),
      keyboardType: TextInputType.url,
      validator: _urlOrEmpty,
    );
    _inDuty = _FieldSpec('운영기관', TextEditingController(text: _t('inDuty')));
    _lctCl = _FieldSpec('환경', TextEditingController(text: _t('lctCl')));
    _lineIntro = _FieldSpec(
        '간략 설명 (lineIntro)', TextEditingController(text: _t('lineIntro')));
    _intro = _FieldSpec('상세 설명 (intro)',
        TextEditingController(text: _t('intro')),
        maxLines: 4);
    _featureNm = _FieldSpec('특징 설명 (featureNm)',
        TextEditingController(text: _t('featureNm')),
        maxLines: 3);
    _reservationWarning = _FieldSpec(
        '예약 주의사항', TextEditingController(text: _t('reservation_warning')),
        maxLines: 3);
    _resveUrl = _FieldSpec('예약 URL', TextEditingController(text: _t('resveUrl')),
        keyboardType: TextInputType.url, validator: _urlOrEmpty);
    _tel = _FieldSpec('전화번호', TextEditingController(text: _t('tel')),
        keyboardType: TextInputType.phone, validator: _phoneOrEmpty);
  }

  @override
  void dispose() {
    for (final f in _fields) {
      f.controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? '필수 입력' : null;

  String? _urlOrEmpty(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final ok = Uri.tryParse(s)?.hasAbsolutePath == true &&
        (s.startsWith('http://') || s.startsWith('https://'));
    return ok ? null : '유효한 URL을 입력하세요';
  }

  String? _phoneOrEmpty(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final reg = RegExp(r'^[0-9\-\+\(\)\s]{6,}$');
    return reg.hasMatch(s) ? null : '유효한 전화번호를 입력하세요';
  }

  // 숫자 + 범위(위도/경도) 검증
  String? _doubleInRange(String? v, double min, double max, String label) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '필수 입력';
    final d = double.tryParse(s);
    if (d == null) return '$label: 숫자를 입력하세요';
    if (d < min || d > max) return '$label: $min ~ $max 범위여야 합니다';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final mapX = double.parse(_mapX.text); // 경도
    final mapY = double.parse(_mapY.text); // 위도

    final data = <String, dynamic>{
      'name': _name.text,
      'location': _location.text,
      'type': _type.text,
      'mapX': mapX,
      'mapY': mapY,
      'contentId': _contentId.text,
      'firstImageUrl': _firstImageUrl.text,
      'inDuty': _inDuty.text,
      'lctCl': _lctCl.text,
      'lineIntro': _lineIntro.text,
      'intro': _intro.text,
      'featureNm': _featureNm.text,
      'reservation_warning': _reservationWarning.text,
      'resveUrl': _resveUrl.text,
      'tel': _tel.text,
    };

    try {
      if (widget.docId == null) {
        await _coll.add({...data, 'createdAt': FieldValue.serverTimestamp()});
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등록되었습니다.')),
        );
      } else {
        await _coll.doc(widget.docId).update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수정되었습니다.')),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.docId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '캠핑장 수정' : '캠핑장 등록')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ..._fields.map(
                    (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: f.controller,
                    decoration: InputDecoration(
                      labelText: f.label,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: f.keyboardType,
                    maxLines: f.maxLines,
                    validator: f.validator ?? _required,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(isEdit ? '수정 완료' : '등록 완료'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldSpec {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int? maxLines;
  final String? Function(String?)? validator;

  _FieldSpec(
      this.label,
      this.controller, {
        this.keyboardType,
        this.maxLines = 1,
        this.validator,
      });

  String get text => controller.text.trim();
}
