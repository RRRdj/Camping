import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../campground_data.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  DateTime? selectedDate;
  final TextEditingController keywordController = TextEditingController();
  List<String> selectedRegions = [];
  List<String> selectedTypes = [];
  late List<String> regionList;

  DateTime _stripTime(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  void initState() {
    super.initState();
    regionList = campgroundList
        .map((camp) => camp['location'].toString().split(' ').first)
        .toSet()
        .toList()
      ..sort();
  }

  void resetFilters() {
    setState(() {
      selectedDate = null;
      keywordController.clear();
      selectedRegions.clear();
      selectedTypes.clear();
    });
  }

  bool get isDateRequired {
    return keywordController.text.trim().isNotEmpty ||
        selectedRegions.isNotEmpty ||
        selectedTypes.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = _stripTime(DateTime.now());
    final DateTime minDate = now.add(const Duration(days: 1));
    final DateTime maxDate = now.add(const Duration(days: 5));

    return Scaffold(
      appBar: AppBar(
        title: const Text('검색 필터 설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: resetFilters,
            tooltip: '필터 초기화',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('예약 날짜 선택', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(selectedDate == null
                      ? '날짜를 선택하세요'
                      : DateFormat('yyyy-MM-dd').format(selectedDate!)),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate != null &&
                          !selectedDate!.isBefore(minDate) &&
                          !selectedDate!.isAfter(maxDate)
                          ? selectedDate!
                          : minDate,
                      firstDate: minDate,
                      lastDate: maxDate,
                      selectableDayPredicate: (day) {
                        return !day.isBefore(minDate) && !day.isAfter(maxDate);
                      },
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                )
              ],
            ),
            const SizedBox(height: 16),
            const Text('키워드 입력', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: keywordController,
              decoration: const InputDecoration(
                hintText: '캠핑장 이름 등',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            const Text('지역 필터', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: regionList.map((region) {
                final isSelected = selectedRegions.contains(region);
                return FilterChip(
                  label: Text(region),
                  selected: isSelected,
                  onSelected: isDateRequired || selectedDate != null
                      ? (bool selected) {
                    setState(() {
                      if (selected) {
                        selectedRegions.add(region);
                      } else {
                        selectedRegions.remove(region);
                      }
                    });
                  }
                      : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('캠핑장 구분', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: ['국립', '지자체'].map((type) {
                final isSelected = selectedTypes.contains(type);
                return FilterChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: isDateRequired || selectedDate != null
                      ? (bool selected) {
                    setState(() {
                      if (selected) {
                        selectedTypes.add(type);
                      } else {
                        selectedTypes.remove(type);
                      }
                    });
                  }
                      : null,
                );
              }).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (isDateRequired && selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('필터를 사용하려면 날짜를 먼저 선택하세요.')),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'selectedDate': selectedDate,
                    'keyword': keywordController.text,
                    'selectedRegions': selectedRegions,
                    'selectedTypes': selectedTypes,
                  });
                },
                icon: const Icon(Icons.search),
                label: const Text('검색하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
