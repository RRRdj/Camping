// lib/screens/admin_user_management_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchField = 'name'; // name, nickname, email 중 선택
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용자 관리')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: '검색어 입력',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _searchField,
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('이름')),
                    DropdownMenuItem(value: 'nickname', child: Text('닉네임')),
                    DropdownMenuItem(value: 'email', child: Text('이메일')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _searchField = v);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy(_searchField) // 간단 정렬
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs.where((doc) {
                  final val = (doc.data()[_searchField] ?? '').toString().toLowerCase();
                  return val.contains(_searchController.text.toLowerCase());
                }).toList();
                if (docs.isEmpty) return const Center(child: Text('검색 결과가 없습니다.'));
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final uid  = docs[i].id;
                    final name = data['name']     as String? ?? '-';
                    final nick = data['nickname'] as String? ?? '-';
                    final email= data['email']    as String? ?? '-';
                    final blocked = data['blocked'] as bool? ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text(name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('닉네임: $nick'),
                            Text('이메일: $email'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blocked ? Colors.grey : Colors.red,
                          ),
                          child: Text(blocked ? '차단 해제' : '차단'),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .update({'blocked': !blocked});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(blocked ? '차단 해제됨' : '차단 처리되었습니다')),
                            );
                          },
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
    );
  }
}
