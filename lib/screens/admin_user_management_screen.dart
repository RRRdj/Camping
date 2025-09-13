import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchField = 'name';
  String _searchText = '';
  Timer? _debounce;

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection('users');

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
      final next = _searchController.text.toLowerCase();
      if (next != _searchText) {
        setState(() => _searchText = next);
      }
    });
  }

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
              stream: _users.orderBy(_searchField).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('로드 실패: ${snap.error}'));
                }
                final all = snap.data?.docs ?? [];
                final filtered =
                    all.where((doc) {
                      final v =
                          (doc.data()[_searchField] ?? '')
                              .toString()
                              .toLowerCase();
                      return _searchText.isEmpty || v.contains(_searchText);
                    }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('검색 결과가 없습니다.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final d = filtered[i];
                    final data = d.data();
                    final uid = d.id;
                    final name = data['name'] as String? ?? '-';
                    final nick = data['nickname'] as String? ?? '-';
                    final email = data['email'] as String? ?? '-';
                    final blocked = data['blocked'] as bool? ?? false;

                    return Card(
                      key: ValueKey(uid),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('닉네임: $nick', overflow: TextOverflow.ellipsis),
                            Text(
                              '이메일: $email',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                blocked ? Colors.grey : Colors.redAccent,
                          ),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: Text(blocked ? '차단 해제' : '차단'),
                                    content: Text(
                                      blocked
                                          ? '해당 사용자의 차단을 해제하시겠습니까?'
                                          : '해당 사용자를 차단하시겠습니까?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, false),
                                        child: const Text('취소'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, true),
                                        child: Text(
                                          blocked ? '해제' : '차단',
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                            );
                            if (ok != true) return;

                            try {
                              await _users.doc(uid).update({
                                'blocked': !blocked,
                              });
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    blocked ? '차단 해제됨' : '차단 처리되었습니다',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('처리 실패: $e')),
                              );
                            }
                          },
                          child: Text(blocked ? '차단 해제' : '차단'),
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
