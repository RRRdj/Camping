import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CampingReservationScreen extends StatefulWidget {
  final Map<String, dynamic> camp;

  const CampingReservationScreen({
    Key? key,
    required this.camp,
  }) : super(key: key);

  @override
  State<CampingReservationScreen> createState() =>
      _CampingReservationScreenState();
}

class _CampingReservationScreenState extends State<CampingReservationScreen> {
  late Future<Map<String, dynamic>> _availabilityFuture;

  @override
  void initState() {
    super.initState();
    _availabilityFuture = _fetchAvailability();
  }

  Future<Map<String, dynamic>> _fetchAvailability() async {
    // camp['name'] 으로 문서 조회
    final doc = await FirebaseFirestore.instance
        .collection('realtime_availability')
        .doc(widget.camp['name'])
        .get();
    if (doc.exists && doc.data() != null) {
      return doc.data() as Map<String, dynamic>;
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.camp['name'] as String;
    return Scaffold(
      appBar: AppBar(
        title: Text('2주일치 예약 현황'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _availabilityFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? {};

            // 내일부터 14일치 날짜 생성
            final today = DateTime.now();
            final start =
            DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
            final dates = List.generate(14, (i) => start.add(Duration(days: i)));

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('날짜')),
                  DataColumn(label: Text('가능/전체')),
                ],
                rows: dates.map((date) {
                  final key = DateFormat('yyyy-MM-dd').format(date);
                  final avail = (data[key] as Map<String, dynamic>?)?['available'] ?? 0;
                  final total = (data[key] as Map<String, dynamic>?)?['total'] ?? 0;
                  return DataRow(cells: [
                    DataCell(Text(DateFormat('MM/dd(E)', 'ko').format(date))),
                    DataCell(Text('$avail / $total')),
                  ]);
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}
