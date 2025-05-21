// lib/screens/camping_reservation_screen.dart
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
    final doc = await FirebaseFirestore.instance
        .collection('realtime_availability')
        .doc(widget.camp['name'])
        .get();
    if (doc.exists && doc.data() != null) {
      return doc.data()! as Map<String, dynamic>;
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('2주일치 예약 현황')),
      body: SafeArea(
        top: false, // AppBar 위쪽은 그대로 두고
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottomInset, // 시스템 바 위로 콘텐츠가 올라오도록
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _availabilityFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data ?? {};

              // 내일부터 14일치 날짜 리스트
              final today = DateTime.now();
              final start = DateTime(today.year, today.month, today.day)
                  .add(const Duration(days: 1));
              final dates =
              List.generate(14, (i) => start.add(Duration(days: i)));

              // 가로 스크롤 + 세로 스크롤을 모두 허용
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('날짜')),
                      DataColumn(label: Text('가능/전체')),
                    ],
                    rows: dates.map((date) {
                      final key = DateFormat('yyyy-MM-dd').format(date);
                      final avail = (data[key] as Map<String, dynamic>?)
                      ?['available'] ??
                          0;
                      final total = (data[key] as Map<String, dynamic>?)
                      ?['total'] ??
                          0;
                      return DataRow(cells: [
                        DataCell(Text(
                            DateFormat('MM/dd(E)', 'ko').format(date))),
                        DataCell(Text('$avail / $total')),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
