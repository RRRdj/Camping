import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  DateTime? selectedDate;
  TextEditingController keywordController = TextEditingController();
  List<String> selectedRegions = [];
  List<String> selectedTypes = [];

  final List<String> regions = ['경북', '경남'];
  final List<String> types = ['국립', '지자체'];

  void _selectDate() async {
    final DateTime today = DateTime.now();
    final DateTime firstDate = today.add(const Duration(days: 1));
    final DateTime lastDate = today.add(const Duration(days: 5));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _toggleRegion(String region) {
    setState(() {
      selectedRegions.contains(region)
          ? selectedRegions.remove(region)
          : selectedRegions.add(region);
    });
  }

  void _toggleType(String type) {
    setState(() {
      selectedTypes.contains(type)
          ? selectedTypes.remove(type)
          : selectedTypes.add(type);
    });
  }

  void _resetFilters() {
    setState(() {
      selectedDate = null;
      keywordController.clear();
      selectedRegions.clear();
      selectedTypes.clear();
    });
  }

  void _submitFilters() {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('날짜는 반드시 선택해야 합니다')),
      );
      return;
    }

    Navigator.pop(context, {
      'selectedDate': selectedDate,
      'keyword': keywordController.text.trim(),
      'selectedRegions': selectedRegions,
      'selectedTypes': selectedTypes,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('검색 필터 설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetFilters,
            tooltip: '초기화',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('예약 날짜 선택', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              title: Text(selectedDate == null
                  ? '날짜를 선택하세요'
                  : DateFormat('yyyy-MM-dd').format(selectedDate!)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
            ),
            const SizedBox(height: 16),

            const Text('키워드 입력', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: keywordController,
              decoration: const InputDecoration(hintText: '캠핑장 이름 등'),
            ),
            const SizedBox(height: 16),

            const Text('지역 필터', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: regions.map((region) {
                final selected = selectedRegions.contains(region);
                return FilterChip(
                  label: Text(region),
                  selected: selected,
                  onSelected: (_) => _toggleRegion(region),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            const Text('캠핑장 구분', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: types.map((type) {
                final selected = selectedTypes.contains(type);
                return FilterChip(
                  label: Text(type),
                  selected: selected,
                  onSelected: (_) => _toggleType(type),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _submitFilters,
              icon: const Icon(Icons.search),
              label: const Text('검색하기'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }
}
