import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../campground_data.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late DateTime defaultDate;
  DateTime? selectedDate;
  final TextEditingController keywordController = TextEditingController();
  List<String> selectedRegions = [];
  List<String> selectedTypes = [];
  late List<String> regionList;

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final now = _stripTime(DateTime.now());
    defaultDate = now.add(const Duration(days: 1));
    selectedDate = defaultDate;
    regionList = campgroundList
        .map((c) => c['location'].toString().split(' ').first)
        .toSet()
        .toList()
      ..sort();
  }

  void resetFilters() {
    setState(() {
      selectedDate = defaultDate;
      keywordController.clear();
      selectedRegions.clear();
      selectedTypes.clear();
    });
  }

  bool get isDateRequired =>
      keywordController.text.trim().isNotEmpty ||
          selectedRegions.isNotEmpty ||
          selectedTypes.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final now = _stripTime(DateTime.now());
    final minDate = now.add(const Duration(days: 1));
    final maxDate = now.add(const Duration(days: 5));

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('검색 필터 설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: resetFilters,
            tooltip: '필터 초기화',
          ),
        ],
      ),
      // 버튼을 화면 하단에 고정, 휴대폰 크기에 맞춰 폭을 채웁니다.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48), // 높이 고정
            ),
            onPressed: () {
              if (isDateRequired && selectedDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('필터를 사용하려면 날짜를 먼저 선택하세요.'),
                  ),
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
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
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
                      selectableDayPredicate: (day) =>
                      !day.isBefore(minDate) && !day.isAfter(maxDate),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                ),
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
                final selected = selectedRegions.contains(region);
                return FilterChip(
                  label: Text(region),
                  selected: selected,
                  onSelected: (isDateRequired || selectedDate != null)
                      ? (bool sel) {
                    setState(() {
                      if (sel) {
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
                final selected = selectedTypes.contains(type);
                return FilterChip(
                  label: Text(type),
                  selected: selected,
                  onSelected: (isDateRequired || selectedDate != null)
                      ? (bool sel) {
                    setState(() {
                      if (sel) {
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
            // 콘텐츠가 길어져도 버튼은 하단에 고정되어 스크롤 영향 없음
          ],
        ),
      ),
    );
  }
}
