// lib/screens/admin_camp_management.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ───────────────────── 목록 + 검색 ─────────────────────
class AdminCampListScreen extends StatefulWidget {
  const AdminCampListScreen({Key? key}) : super(key: key);

  @override
  State<AdminCampListScreen> createState() => _AdminCampListScreenState();
}

class _AdminCampListScreenState extends State<AdminCampListScreen> {
  final _searchCtr = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtr.dispose();
    super.dispose();
  }

  bool _matches(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final name = (data['name'] ?? '').toString().toLowerCase();
    final location = (data['location'] ?? '').toString().toLowerCase();
    return name.contains(q) || location.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('캠핑장 목록 관리')),
      body: Column(
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtr,
              decoration: InputDecoration(
                hintText: '이름 또는 지역으로 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtr.clear();
                    setState(() => _query = '');
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // 필요 시 .orderBy('name') 추가 가능
              stream: FirebaseFirestore.instance
                  .collection('campgrounds')
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('로드 실패: ${snap.error}'));
                }
                final allDocs = snap.data!.docs;
                final filtered = allDocs
                    .where((d) => _matches(d.data()! as Map<String, dynamic>))
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('검색 결과가 없습니다.'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx2, i) {
                    final doc = filtered[i];
                    final data = doc.data()! as Map<String, dynamic>;
                    final name = (data['name'] ?? '') as String;
                    final location = (data['location'] ?? '') as String;
                    final type = (data['type'] ?? '') as String;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.park, color: Colors.teal),
                        title: Text(name),
                        // ✅ 위도/경도 표시 없음
                        subtitle: Text('$location • $type'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
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
                              icon:
                              const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx3) => AlertDialog(
                                    title: const Text('삭제 확인'),
                                    content: const Text('정말 삭제하시겠습니까?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx3, false),
                                        child: const Text('취소'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx3, true),
                                        child: const Text('삭제',
                                            style:
                                            TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await FirebaseFirestore.instance
                                      .collection('campgrounds')
                                      .doc(doc.id)
                                      .delete();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('삭제되었습니다.')),
                                  );
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminCampFormScreen()),
          );
        },
        child: const Icon(Icons.add),
        tooltip: '신규 캠핑장 추가',
      ),
    );
  }
}

/// ───────────────────── 등록/수정 폼 ─────────────────────
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
  late TextEditingController _nameCtr;
  late TextEditingController _locationCtr;
  late TextEditingController _typeCtr;
  late TextEditingController _contentIdCtr;
  late TextEditingController _firstImageUrlCtr;
  late TextEditingController _inDutyCtr;
  late TextEditingController _lctClCtr;
  late TextEditingController _lineIntroCtr;
  late TextEditingController _introCtr;
  late TextEditingController _featureNmCtr;
  late TextEditingController _reservationWarningCtr;
  late TextEditingController _resveUrlCtr;
  late TextEditingController _telCtr;
  late TextEditingController _mapXCtr; // 경도(lng)
  late TextEditingController _mapYCtr; // 위도(lat)

  @override
  void initState() {
    super.initState();
    final d = widget.existingData;
    _nameCtr = TextEditingController(text: d?['name']);
    _locationCtr = TextEditingController(text: d?['location']);
    _typeCtr = TextEditingController(text: d?['type']);
    _contentIdCtr = TextEditingController(text: d?['contentId']);
    _firstImageUrlCtr = TextEditingController(text: d?['firstImageUrl']);
    _inDutyCtr = TextEditingController(text: d?['inDuty']);
    _lctClCtr = TextEditingController(text: d?['lctCl']);
    _lineIntroCtr = TextEditingController(text: d?['lineIntro']);
    _introCtr = TextEditingController(text: d?['intro']);
    _featureNmCtr = TextEditingController(text: d?['featureNm']);
    _reservationWarningCtr =
        TextEditingController(text: d?['reservation_warning']);
    _resveUrlCtr = TextEditingController(text: d?['resveUrl']);
    _telCtr = TextEditingController(text: d?['tel']);
    _mapXCtr = TextEditingController(text: d?['mapX']?.toString());
    _mapYCtr = TextEditingController(text: d?['mapY']?.toString());
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _locationCtr.dispose();
    _typeCtr.dispose();
    _contentIdCtr.dispose();
    _firstImageUrlCtr.dispose();
    _inDutyCtr.dispose();
    _lctClCtr.dispose();
    _lineIntroCtr.dispose();
    _introCtr.dispose();
    _featureNmCtr.dispose();
    _reservationWarningCtr.dispose();
    _resveUrlCtr.dispose();
    _telCtr.dispose();
    _mapXCtr.dispose();
    _mapYCtr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final x = double.tryParse(_mapXCtr.text.trim());
    final y = double.tryParse(_mapYCtr.text.trim());
    if (x == null || y == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('좌표(mapX/mapY)를 올바른 숫자로 입력하세요.')),
      );
      return;
    }

    final data = {
      'name': _nameCtr.text.trim(),
      'location': _locationCtr.text.trim(),
      'type': _typeCtr.text.trim(),
      'contentId': _contentIdCtr.text.trim(),
      'firstImageUrl': _firstImageUrlCtr.text.trim(),
      'inDuty': _inDutyCtr.text.trim(),
      'lctCl': _lctClCtr.text.trim(),
      'lineIntro': _lineIntroCtr.text.trim(),
      'intro': _introCtr.text.trim(),
      'featureNm': _featureNmCtr.text.trim(),
      'reservation_warning': _reservationWarningCtr.text.trim(),
      'resveUrl': _resveUrlCtr.text.trim(),
      'tel': _telCtr.text.trim(),
      'mapX': x, // 경도(lng)
      'mapY': y, // 위도(lat)
      'createdAt': FieldValue.serverTimestamp(),
    };

    final coll = FirebaseFirestore.instance.collection('campgrounds');
    if (widget.docId == null) {
      await coll.add(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('등록되었습니다.')));
    } else {
      await coll.doc(widget.docId).update(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('수정되었습니다.')));
    }
    if (mounted) Navigator.pop(context);
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
              for (final item in <Map<String, dynamic>>[
                {'label': '이름', 'ctrl': _nameCtr},
                {'label': '위치', 'ctrl': _locationCtr},
                {'label': '유형', 'ctrl': _typeCtr},
                {'label': '경도 (mapX)', 'ctrl': _mapXCtr, 'numeric': true},
                {'label': '위도 (mapY)', 'ctrl': _mapYCtr, 'numeric': true},
                {'label': '콘텐츠 ID', 'ctrl': _contentIdCtr},
                {'label': '이미지 URL', 'ctrl': _firstImageUrlCtr},
                {'label': '운영기관', 'ctrl': _inDutyCtr},
                {'label': '환경', 'ctrl': _lctClCtr},
                {'label': '간략 설명 (lineIntro)', 'ctrl': _lineIntroCtr},
                {'label': '상세 설명 (intro)', 'ctrl': _introCtr},
                {'label': '특징 설명 (featureNm)', 'ctrl': _featureNmCtr},
                {'label': '예약 주의사항', 'ctrl': _reservationWarningCtr},
                {'label': '예약 URL', 'ctrl': _resveUrlCtr},
                {'label': '전화번호', 'ctrl': _telCtr},
              ]) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: item['ctrl'] as TextEditingController,
                    decoration: InputDecoration(
                      labelText: item['label'] as String,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: (item['numeric'] == true)
                        ? const TextInputType.numberWithOptions(
                        decimal: true, signed: true)
                        : TextInputType.text,
                    inputFormatters: (item['numeric'] == true)
                        ? [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))]
                        : const [],
                    validator: (v) {
                      if (v == null || v.isEmpty) return '필수 입력';
                      if (item['numeric'] == true &&
                          double.tryParse(v.trim()) == null) {
                        return '숫자 형식으로 입력(예: 127.123456)';
                      }
                      return null;
                    },
                  ),
                ),
              ],
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48)),
                child: Text(isEdit ? '수정 완료' : '등록 완료'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
