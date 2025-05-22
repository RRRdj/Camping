// lib/screens/camping_reservation_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

// 기상청 서비스키 (URL-encoded)
const _serviceKey =
    '0wd8kVe4L75w5XaOYAd9iM0nbI9lgSRJLIDVsN78hfbIauGBbgdIqrwWDC%2B%2F10qT4MMw6KSWAAlB6dXNuGEpLQ%3D%3D';

class CampingReservationScreen extends StatefulWidget {
  /// camp: 'name', 'addr1'
  final Map<String, dynamic> camp;
  const CampingReservationScreen({Key? key, required this.camp})
    : super(key: key);
  @override
  State<CampingReservationScreen> createState() =>
      _CampingReservationScreenState();
}

class _CampingReservationScreenState extends State<CampingReservationScreen> {
  late Future<Map<String, dynamic>> _availabilityFuture;
  late Future<Map<String, String>> _weatherFuture;

  @override
  void initState() {
    super.initState();
    _availabilityFuture = _fetchAvailability();
    _weatherFuture = _fetchWeather();
  }

  Future<Map<String, dynamic>> _fetchAvailability() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('realtime_availability')
            .doc(widget.camp['name'])
            .get();
    return (doc.exists && doc.data() != null) ? doc.data()! : {};
  }

  Future<Map<String, String>> _fetchWeather() async {
    try {
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day);
      final tmFc =
          now.hour >= 18
              ? DateFormat('yyyyMMdd').format(base) + '1800'
              : now.hour >= 6
              ? DateFormat('yyyyMMdd').format(base) + '0600'
              : DateFormat(
                    'yyyyMMdd',
                  ).format(base.subtract(const Duration(days: 1))) +
                  '1800';

      // 권역 매핑 로직 제거: addr1은 더 이상 사용하지 않음
      const defaultRegId = '11B00000';
      final regId = defaultRegId;

      final url = Uri.parse(
        'https://apis.data.go.kr/1360000/MidFcstInfoService/getMidLandFcst'
        '?serviceKey=$_serviceKey&pageNo=1&numOfRows=10&dataType=XML&regId=$regId&tmFc=$tmFc',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return {};

      final xmlDoc = xml.XmlDocument.parse(res.body);
      final item = xmlDoc.findAllElements('item').first;
      final Map<String, String> weather = {};
      const offsets = {
        'wf4Pm': 3,
        'wf5Pm': 4,
        'wf6Pm': 5,
        'wf7Pm': 6,
        'wf8': 7,
        'wf9': 8,
        'wf10': 9,
      };
      for (final e in item.children.whereType<xml.XmlElement>()) {
        final d = offsets[e.name.local];
        if (d == null) continue;
        final key = DateFormat(
          'yyyy-MM-dd',
        ).format(base.add(Duration(days: d)));
        weather[key] = e.text;
      }
      return weather;
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(title: const Text('2주일치 예약 현황')),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, inset),
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait([_availabilityFuture, _weatherFuture]),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || snap.data == null || snap.data!.length < 2) {
              return const Center(child: Text('데이터를 불러올 수 없습니다.'));
            }
            final avail = snap.data![0] as Map<String, dynamic>;
            final weather = snap.data![1] as Map<String, String>;
            final today = DateTime.now();
            final start = DateTime(
              today.year,
              today.month,
              today.day,
            ).add(const Duration(days: 1));
            final dates = List.generate(
              14,
              (i) => start.add(Duration(days: i)),
            );

            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('날짜')),
                    DataColumn(label: Text('가능/전체')),
                    DataColumn(label: Text('날씨')),
                  ],
                  rows:
                      dates.map((d) {
                        final k = DateFormat('yyyy-MM-dd').format(d);
                        final e = avail[k] as Map<String, dynamic>?;
                        final a = e?['available'] ?? 0;
                        final t = e?['total'] ?? 0;
                        final w = weather[k] ?? '-';
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(DateFormat('MM/dd(E)', 'ko').format(d)),
                            ),
                            DataCell(Text('$a / $t')),
                            DataCell(Text(w)),
                          ],
                        );
                      }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
