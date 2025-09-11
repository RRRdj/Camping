// lib/screens/admin_camp_management.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCampListScreen extends StatelessWidget {
  const AdminCampListScreen({Key? key}) : super(key: key);

  CollectionReference<Map<String, dynamic>> get _coll =>
      FirebaseFirestore.instance.collection('campgrounds');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('캠핑장 목록 관리')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (ctx2, i) {
              final doc = docs[i];
              final data = doc.data();
              final name = (data['name'] ?? '') as String;
              final location = (data['location'] ?? '') as String;
              final type = (data['type'] ?? '') as String;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  key: ValueKey(doc.id),
                  leading: const Icon(Icons.park, color: Colors.teal),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$location • $type',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                              builder:
                                  (_) => AdminCampFormScreen(
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
                            builder:
                                (ctx3) => AlertDialog(
                                  title: const Text('삭제 확인'),
                                  content: Text('“$name” 항목을 삭제하시겠습니까?'),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(ctx3, false),
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(ctx3, true),
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
                                  const SnackBar(content: Text('삭제되었습니다.')),
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
      floatingActionButton: FloatingActionButton(
        tooltip: '신규 캠핑장 추가',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminCampFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

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
    _contentId = _FieldSpec(
      '콘텐츠 ID',
      TextEditingController(text: _t('contentId')),
    );
    _firstImageUrl = _FieldSpec(
      '이미지 URL',
      TextEditingController(text: _t('firstImageUrl')),
      keyboardType: TextInputType.url,
      validator: _urlOrEmpty,
    );
    _inDuty = _FieldSpec('운영기관', TextEditingController(text: _t('inDuty')));
    _lctCl = _FieldSpec('환경', TextEditingController(text: _t('lctCl')));
    _lineIntro = _FieldSpec(
      '간략 설명 (lineIntro)',
      TextEditingController(text: _t('lineIntro')),
    );
    _intro = _FieldSpec(
      '상세 설명 (intro)',
      TextEditingController(text: _t('intro')),
      maxLines: 4,
    );
    _featureNm = _FieldSpec(
      '특징 설명 (featureNm)',
      TextEditingController(text: _t('featureNm')),
      maxLines: 3,
    );
    _reservationWarning = _FieldSpec(
      '예약 주의사항',
      TextEditingController(text: _t('reservation_warning')),
      maxLines: 3,
    );
    _resveUrl = _FieldSpec(
      '예약 URL',
      TextEditingController(text: _t('resveUrl')),
      keyboardType: TextInputType.url,
      validator: _urlOrEmpty,
    );
    _tel = _FieldSpec(
      '전화번호',
      TextEditingController(text: _t('tel')),
      keyboardType: TextInputType.phone,
      validator: _phoneOrEmpty,
    );
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
    final ok =
        Uri.tryParse(s)?.hasAbsolutePath == true &&
        (s.startsWith('http://') || s.startsWith('https://'));
    return ok ? null : '유효한 URL을 입력하세요';
  }

  String? _phoneOrEmpty(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    // 매우 느슨한 휴대전화/전화 번호 검증
    final reg = RegExp(r'^[0-9\-\+\(\)\s]{6,}$');
    return reg.hasMatch(s) ? null : '유효한 전화번호를 입력하세요';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'name': _name.text,
      'location': _location.text,
      'type': _type.text,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('등록되었습니다.')));
      } else {
        await _coll.doc(widget.docId).update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('수정되었습니다.')));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
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
