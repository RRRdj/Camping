import 'package:flutter/material.dart';

class AdminCampListScreen extends StatelessWidget {
  const AdminCampListScreen({Key? key}) : super(key: key);

  final List<Map<String, String>> dummyCampList = const [
    {
      'name': '구미 금오산 야영장',
      'location': '경북 구미시',
      'type': '지자체야영장',
    },
    {
      'name': '소백산 삼가야영장',
      'location': '경북 영주시',
      'type': '국립공원 야영장',
    },
    {
      'name': '속초 해변 캠핑장',
      'location': '강원 속초시',
      'type': '민간 캠핑장',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('캠핑장 목록 관리')),
      body: ListView.builder(
        itemCount: dummyCampList.length,
        itemBuilder: (context, index) {
          final camp = dummyCampList[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.park, color: Colors.teal),
              title: Text(camp['name']!),
              subtitle: Text('${camp['location']} • ${camp['type']}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey),
                onPressed: () {
                  Navigator.pushNamed(context, '/admin/camp_edit');
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 등록 페이지 이동 예정
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('등록 기능은 아직 구현되지 않았습니다.')),
          );
        },
        child: const Icon(Icons.add),
        tooltip: '신규 캠핑장 추가',
      ),
    );
  }
}
