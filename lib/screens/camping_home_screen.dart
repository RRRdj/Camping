import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../campground_data.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// CampingHomeScreen
/// ─────────────────────────────────────────────────────────────────────────
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
  // ---------------- 상태 ----------------
  List<Map<String, dynamic>> filteredCamps = [];
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  final TextEditingController keywordController = TextEditingController();
  final List<String> selectedRegions = [];
  final List<String> selectedTypes = [];
  late final List<String> regionList;
  Map<String, Map<String, dynamic>> availabilityCache = {};

  // ---------------- 라이프사이클 ----------------
  @override
  void initState() {
    super.initState();
    regionList =
        campgroundList
            .map((c) => c['location'].toString().split(' ').first)
            .toSet()
            .toList()
          ..sort();
    _applyFilters();
  }

  @override
  void dispose() {
    keywordController.dispose();
    super.dispose();
  }

  // ---------------- Firestore ----------------
  Future<Map<String, dynamic>?> _fetchAvailability(String campName) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('realtime_availability')
              .doc(campName)
              .get();
      if (snapshot.exists) {
        final data = snapshot.data();
        final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
        if (data != null && data.containsKey(dateKey)) return data[dateKey];
      }
    } catch (e) {
      debugPrint('❗ Firestore 오류: $e');
    }
    return null;
  }

  // ---------------- 필터 ----------------
  void _applyFilters() async {
    availabilityCache.clear();
    var target = List<Map<String, dynamic>>.from(campgroundList);

    final keyword = keywordController.text.trim().toLowerCase();
    target =
        target.where((camp) {
          final matchKeyword = camp['name'].toString().toLowerCase().contains(
            keyword,
          );
          final matchRegion =
              selectedRegions.isEmpty ||
              selectedRegions.any((r) => camp['location'].contains(r));
          final matchType =
              selectedTypes.isEmpty || selectedTypes.contains(camp['type']);
          return matchKeyword && matchRegion && matchType;
        }).toList();

    // 가용성 정보 병렬 취득
    await Future.wait(
      target.map((camp) async {
        final data = await _fetchAvailability(camp['name']);
        if (data != null) availabilityCache[camp['name']] = data;
      }),
    );

    // 정렬
    target.sort((a, b) {
      final aAv = (availabilityCache[a['name']] ?? {})['available'] ?? 0;
      final bAv = (availabilityCache[b['name']] ?? {})['available'] ?? 0;
      final aClosed = aAv == 0;
      final bClosed = bAv == 0;
      if (aClosed && !bClosed) return 1;
      if (!aClosed && bClosed) return -1;
      if (aClosed && bClosed) return a['name'].compareTo(b['name']);
      return 0;
    });

    if (!mounted) return;
    setState(() => filteredCamps = target);
  }

  void _resetFilters() {
    setState(() {
      selectedDate = DateTime.now().add(const Duration(days: 1));
      keywordController.clear();
      selectedRegions.clear();
      selectedTypes.clear();
    });
    _applyFilters();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('금오캠핑'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '검색',
            onPressed: () async {
              final result = await showSearch<String?>(
                context: context,
                delegate: _CampSearchDelegate(camps: campgroundList),
              );
              if (result != null && mounted) {
                setState(() => keywordController.text = result);
                _applyFilters();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            selectedDate: selectedDate,
            regionList: regionList,
            selectedRegions: selectedRegions,
            selectedTypes: selectedTypes,
            onDateChanged: (d) {
              setState(() => selectedDate = d);
              _applyFilters();
            },
            onRegionsSet: (list) {
              setState(() {
                selectedRegions
                  ..clear()
                  ..addAll(list);
              });
              _applyFilters();
            },
            onTypesSet: (list) {
              setState(() {
                selectedTypes
                  ..clear()
                  ..addAll(list);
              });
              _applyFilters();
            },
            onReset: _resetFilters,
            keywordController: keywordController,
            onKeywordChanged: () => _applyFilters(),
          ),
          Expanded(
            child:
                filteredCamps.isEmpty
                    ? const _NoResultWidget()
                    : ListView.builder(
                      itemCount: filteredCamps.length,
                      itemBuilder: (c, i) {
                        final camp = filteredCamps[i];
                        final cache = availabilityCache[camp['name']] ?? {};
                        final available = cache['available'] ?? 0;
                        final total = cache['total'] ?? 0;
                        return _CampItem(
                          camp: camp,
                          isAvailable: available > 0,
                          available: available,
                          total: total,
                          isBookmarked: widget.bookmarked[camp['name']] == true,
                          onToggleBookmark: widget.onToggleBookmark,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Filter Bar (날짜/지역/숙소 유형/초기화)
/// ─────────────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selectedDate,
    required this.regionList,
    required this.selectedRegions,
    required this.selectedTypes,
    required this.onDateChanged,
    required this.onRegionsSet,
    required this.onTypesSet,
    required this.onReset,
    required this.keywordController,
    required this.onKeywordChanged,
  });

  final DateTime selectedDate;
  final List<String> regionList;
  final List<String> selectedRegions;
  final List<String> selectedTypes;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<List<String>> onRegionsSet;
  final ValueChanged<List<String>> onTypesSet;
  final VoidCallback onReset;
  final TextEditingController keywordController;
  final VoidCallback onKeywordChanged;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0D6284);
    const txtStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    );

    final dateText = DateFormat('yyyy.MM.dd').format(selectedDate);
    final regionLabel =
        selectedRegions.isEmpty
            ? '지역'
            : selectedRegions.length == 1
            ? selectedRegions[0]
            : '${selectedRegions[0]} 외 ${selectedRegions.length - 1}';
    final typeLabel =
        selectedTypes.isEmpty
            ? '숙소 유형'
            : selectedTypes.length == 1
            ? selectedTypes[0]
            : '${selectedTypes[0]} 외 ${selectedTypes.length - 1}';

    return Container(
      color: const Color(0xFFE46F2E),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // 날짜 선택
          _BlueButton(
            onPressed: () async {
              final now = DateTime.now();
              final min = now.add(const Duration(days: 1));
              final max = now.add(const Duration(days: 5));
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    selectedDate.isAfter(max) || selectedDate.isBefore(min)
                        ? min
                        : selectedDate,
                firstDate: min,
                lastDate: max,
              );
              if (picked != null) onDateChanged(picked);
            },
            child: Row(
              children: [
                Text(dateText, style: txtStyle),
                const SizedBox(width: 4),
                const Icon(Icons.calendar_today, color: Colors.white, size: 16),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 지역 선택
          Expanded(
            child: _BlueButton(
              onPressed: () async {
                final sel = await showModalBottomSheet<List<String>>(
                  context: context,
                  isScrollControlled: true,
                  builder:
                      (_) => _MultiSelectSheet(
                        title: '지역 선택',
                        options: regionList,
                        initialSelected: selectedRegions,
                      ),
                );
                if (sel != null) onRegionsSet(sel);
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      regionLabel,
                      style: txtStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 숙소 유형
          Expanded(
            child: _BlueButton(
              onPressed: () async {
                final sel = await showModalBottomSheet<List<String>>(
                  context: context,
                  isScrollControlled: true,
                  builder:
                      (_) => const _MultiSelectSheet(
                        title: '숙소 유형 선택',
                        options: ['국립', '지자체'],
                        initialSelected: [],
                      ),
                );
                if (sel != null) onTypesSet(sel);
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      typeLabel,
                      style: txtStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 초기화
          IconButton(
            icon: const Icon(Icons.refresh, color: blue),
            onPressed: onReset,
          ),
        ],
      ),
    );
  }
}

class _BlueButton extends StatelessWidget {
  const _BlueButton({required this.child, required this.onPressed});
  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D6284),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(0, 40),
      ),
      onPressed: onPressed,
      child: child,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Multi-select BottomSheet
/// ─────────────────────────────────────────────────────────────────────────
class _MultiSelectSheet extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.initialSelected,
  });
  final String title;
  final List<String> options;
  final List<String> initialSelected;

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late List<String> tempSelected;
  @override
  void initState() {
    super.initState();
    tempSelected = List.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: widget.options.length,
                itemBuilder: (_, i) {
                  final opt = widget.options[i];
                  final checked = tempSelected.contains(opt);
                  return CheckboxListTile(
                    title: Text(opt),
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        checked
                            ? tempSelected.remove(opt)
                            : tempSelected.add(opt);
                      });
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, tempSelected),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// 캠핑장 카드 + 결과 없음 위젯
/// ─────────────────────────────────────────────────────────────────────────
class _CampItem extends StatelessWidget {
  const _CampItem({
    required this.camp,
    required this.isAvailable,
    required this.available,
    required this.total,
    required this.isBookmarked,
    required this.onToggleBookmark,
  });
  final Map<String, dynamic> camp;
  final bool isAvailable;
  final int available;
  final int total;
  final bool isBookmarked;
  final void Function(String) onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final name = camp['name'];
    return Opacity(
      opacity: isAvailable ? 1 : 0.4,
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
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            isBookmarked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isBookmarked ? Colors.red : Colors.grey,
                          ),
                          onPressed: () => onToggleBookmark(name),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${camp['location']} | ${camp['type']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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
                onPressed:
                    () => Navigator.pushNamed(context, '/camping_info_screen'),
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

class _NoResultWidget extends StatelessWidget {
  const _NoResultWidget();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey),
          SizedBox(height: 12),
          Text('조건에 맞는 캠핑장이 없습니다.', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// SearchDelegate (간단 검색창)
/// ─────────────────────────────────────────────────────────────────────────
class _CampSearchDelegate extends SearchDelegate<String?> {
  _CampSearchDelegate({required this.camps});
  final List<Map<String, dynamic>> camps;

  @override
  String? get searchFieldLabel => '캠핑장 검색';

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final filtered =
        camps
            .where(
              (c) => c['name'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
    if (filtered.isEmpty) {
      return const Center(child: Text('결과 없음'));
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final camp = filtered[index];
        return ListTile(
          leading: const Icon(Icons.park),
          title: Text(camp['name']),
          subtitle: Text('${camp['location']} | ${camp['type']}'),
          onTap: () => close(context, camp['name']), // 캠핑장 이름 반환
        );
      },
    );
  }
}
