
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CampingReservationScreen extends StatefulWidget {
  final Map<String, dynamic> camp;

  const CampingReservationScreen({Key? key, required this.camp})
      : super(key: key);

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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('2주일치 예약 현황')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottomInset,
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _availabilityFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data ?? {};


              final today = DateTime.now();
              final start =
              DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
              final dates = List.generate(
                14,
                    (i) => start.add(Duration(days: i)),
              );

              return ListView.separated(
                itemCount: dates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final date = dates[i];
                  final key = DateFormat('yyyy-MM-dd').format(date);
                  final avail = (data[key] as Map<String, dynamic>?)?['available'] ?? 0;
                  final total = (data[key] as Map<String, dynamic>?)?['total'] ?? 0;

                  return _ReservationTile(
                    date: date,
                    avail: avail,
                    total: total,
                    colorScheme: cs,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}


class _ReservationTile extends StatelessWidget {
  final DateTime date;
  final int avail;
  final int total;
  final ColorScheme colorScheme;

  const _ReservationTile({
    required this.date,
    required this.avail,
    required this.total,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('MM/dd(E)', 'ko').format(date);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$avail / $total',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),


            _CapacityGauge(avail: avail, total: total),
          ],
        ),
      ),
    );
  }
}


class _CapacityGauge extends StatelessWidget {
  final int avail;
  final int total;

  const _CapacityGauge({required this.avail, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final double value;
    final Color color;

    if (total <= 0) {
      value = 0.0;
      color = cs.surfaceVariant;
    } else if (avail <= 0) {

      value = 1.0;
      color = const Color(0xFFEF4444);
    } else {
      value = (avail / total).clamp(0.0, 1.0);
      if (value <= 0.4) {
        color = const Color(0xFFF97316);
      } else {
        color = const Color(0xFF22C55E);
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 10,
        backgroundColor: cs.surfaceVariant,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
