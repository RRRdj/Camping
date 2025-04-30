import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../campground_data.dart';

class CampingHomeScreen extends StatefulWidget {
  final Map<String, bool> bookmarked;
  final void Function(String name) onToggleBookmark;

  const CampingHomeScreen({
    super.key,
    required this.bookmarked,
    required this.onToggleBookmark,
  });

  @override
  State<CampingHomeScreen> createState() => _CampingHomeScreenState();
}

class _CampingHomeScreenState extends State<CampingHomeScreen> {
  List<Map<String, dynamic>> filteredCamps = [];
  late String selectedDate;
  DateTime? selectedDateObj;
  String keyword = '';
  List<String> selectedRegions = [];
  List<String> selectedTypes = [];

  @override
  void initState() {
    super.initState();
    final DateTime defaultDate = DateTime.now().add(const Duration(days: 1));
    selectedDateObj = defaultDate;
    selectedDate = DateFormat('yyyy-MM-dd').format(selectedDateObj!);
    applyFilters();
  }

  void applyFilters() {
    List<Map<String, dynamic>> target = List.from(campgroundList);

    target = target.where((camp) {
      final matchKeyword = camp['name'].toString().toLowerCase().contains(keyword.toLowerCase());
      final matchRegion = selectedRegions.isEmpty || selectedRegions.any((r) => camp['location'].contains(r));
      final matchType = selectedTypes.isEmpty || selectedTypes.contains(camp['type']);
      return matchKeyword && matchRegion && matchType;
    }).toList();

    setState(() {
      filteredCamps = target;
    });
  }

  Future<Map<String, dynamic>?> fetchAvailability(String campName) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('realtime_availability')
          .doc(campName)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && selectedDate.isNotEmpty && data.containsKey(selectedDate)) {
          return data[selectedDate];
        }
      }
    } catch (e) {
      print('❗ Firestore 오류: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('금오캠핑'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/search');
              if (result is Map<String, dynamic>) {
                selectedDateObj = result['selectedDate'];
                selectedDate = DateFormat('yyyy-MM-dd').format(selectedDateObj!);
                keyword = result['keyword'];
                selectedRegions = List<String>.from(result['selectedRegions']);
                selectedTypes = List<String>.from(result['selectedTypes']);
                applyFilters();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: filteredCamps.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 60, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('조건에 맞는 캠핑장이 없습니다.', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
                : ListView.builder(
              itemCount: filteredCamps.length,
              itemBuilder: (context, index) {
                final camp = filteredCamps[index];
                return FutureBuilder<Map<String, dynamic>?> (
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
          ),
        ],
      ),
    );
  }

  Widget _buildCampItem(Map<String, dynamic> camp, int available, int total, bool isAvailable) {
    final name = camp['name'];
    final isBookmarked = widget.bookmarked[name] == true;

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.4,
      child: Card(
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
                    Row(
                      children: [
                        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isBookmarked ? Icons.favorite : Icons.favorite_border,
                            color: isBookmarked ? Colors.red : Colors.grey,
                          ),
                          onPressed: () {
                            widget.onToggleBookmark(name);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${camp['location']} | ${camp['type']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                  Navigator.pushNamed(context, '/camping_info_screen');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAvailable ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                ),
                child: const Text('둘러보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}