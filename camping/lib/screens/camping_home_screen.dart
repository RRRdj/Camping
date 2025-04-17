import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CampingHomeScreen extends StatefulWidget {
  const CampingHomeScreen({Key? key}) : super(key: key);

  @override
  State<CampingHomeScreen> createState() => _CampingHomeScreenState();
}

class _CampingHomeScreenState extends State<CampingHomeScreen> {
  final List<Map<String, dynamic>> campingList = [
    {'name': '백운동'},
    {'name': '삼정'},
    {'name': '치인'},
  ];

  Future<Map<String, dynamic>?> fetchAvailability(String campName) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('realtime_availability')
        .doc(campName)
        .get();

    if (snapshot.exists) {
      final data = snapshot.data();

      final koreaNow = DateTime.now().toUtc().add(const Duration(hours: 9));
      final tomorrow = DateFormat('yyyy-MM-dd')
          .format(koreaNow.add(const Duration(days: 1)));

      print('📦 Firestore date: ${data?['date']}, Tomorrow: $tomorrow');

      if (data != null && data['date'].toString() == tomorrow) {
        return data;
      }
    }
    return null;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('금오캠핑')),
      body: ListView.builder(
        itemCount: campingList.length,
        itemBuilder: (context, index) {
          final camp = campingList[index];
          return FutureBuilder<Map<String, dynamic>?>(
            future: fetchAvailability(camp['name']),
            builder: (context, snapshot) {
              final available = snapshot.data?['available'] ?? 0;
              final total = snapshot.data?['total'] ?? 0;
              final isAvailable = available > 0;
              return _buildCampItem(camp, available, total, isAvailable);
            },
          );
        },
      ),
    );
  }

  Widget _buildCampItem(
      Map<String, dynamic> camp, int available, int total, bool isAvailable) {
    final location = camp['location'] ?? '지역정보';
    final name = camp['name'] ?? '캠핑장 이름';
    final type = camp['type'] ?? '구분 없음';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.park, size: 48, color: Colors.teal),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$location | $type',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Text(
                    isAvailable
                        ? '예약 가능 ($available/$total)'
                        : '예약 마감 ($available/$total)',
                    style: TextStyle(
                      color: isAvailable ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/camping_info');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isAvailable ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('캠핑장 둘러보기'),
            ),
          ],
        ),
      ),
    );
  }
}
