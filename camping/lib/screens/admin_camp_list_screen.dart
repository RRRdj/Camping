// lib/screens/admin_camp_management.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 관리자 캠핑장 목록 및 CRUD 화면 (등록/수정 폼 포함)
class AdminCampListScreen extends StatelessWidget {
  const AdminCampListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('캠핑장 목록 관리')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('campgrounds').snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('로드 실패: ${snap.error}'));
          }
          final docs = snap.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx2, i) {
              final doc = docs[i];
              final data = doc.data()! as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.park, color: Colors.teal),
                  title: Text(data['name'] ?? ''),
                  subtitle: Text('${data['location'] ?? ''} • ${data['type'] ?? ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 수정 아이콘을 먼저 배치
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminCampFormScreen(docId: doc.id, existingData: data),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx3) => AlertDialog(
                              title: const Text('삭제 확인'),
                              content: const Text('정말 삭제하시겠습니까?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx3, false), child: const Text('취소')),
                                TextButton(onPressed: () => Navigator.pop(ctx3, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await FirebaseFirestore.instance.collection('campgrounds').doc(doc.id).delete();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
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

/// 캠핑장 등록/수정 폼 (available/total 필드 제외)
class AdminCampFormScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? existingData;

  const AdminCampFormScreen({Key? key, this.docId, this.existingData}) : super(key: key);

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
  late TextEditingController _resveUrlCtr;
  late TextEditingController _telCtr;

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
    _resveUrlCtr = TextEditingController(text: d?['resveUrl']);
    _telCtr = TextEditingController(text: d?['tel']);
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
    _resveUrlCtr.dispose();
    _telCtr.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final data = {
      'name': _nameCtr.text.trim(),
      'location': _locationCtr.text.trim(),
      'type': _typeCtr.text.trim(),
      'contentId': _contentIdCtr.text.trim(),
      'firstImageUrl': _firstImageUrlCtr.text.trim(),
      'inDuty': _inDutyCtr.text.trim(),
      'lctCl': _lctClCtr.text.trim(),
      'lineIntro': _lineIntroCtr.text.trim(),
      'resveUrl': _resveUrlCtr.text.trim(),
      'tel': _telCtr.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    final coll = FirebaseFirestore.instance.collection('campgrounds');
    if (widget.docId == null) {
      await coll.add(data);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('등록되었습니다.')));
    } else {
      await coll.doc(widget.docId).update(data);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수정되었습니다.')));
    }
    Navigator.pop(context);
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
              for (var item in [
                {'label': '이름', 'ctrl': _nameCtr},
                {'label': '위치', 'ctrl': _locationCtr},
                {'label': '유형', 'ctrl': _typeCtr},
                {'label': '콘텐츠 ID', 'ctrl': _contentIdCtr},
                {'label': '이미지 URL', 'ctrl': _firstImageUrlCtr},
                {'label': '운영기관', 'ctrl': _inDutyCtr},
                {'label': '환경', 'ctrl': _lctClCtr},
                {'label': '설명', 'ctrl': _lineIntroCtr},
                {'label': '예약 URL', 'ctrl': _resveUrlCtr},
                {'label': '전화번호', 'ctrl': _telCtr},
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: item['ctrl'] as TextEditingController,
                    decoration: InputDecoration(
                      labelText: item['label'] as String,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? '필수 입력' : null,
                  ),
                ),
              ElevatedButton(
                onPressed: _save,
                child: Text(isEdit ? '수정 완료' : '등록 완료'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}