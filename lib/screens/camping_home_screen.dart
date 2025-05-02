import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../campground_data.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// CampingHomeScreen – 리디자인 버전 (단색, 라이트 테마)
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
  List<Map<String, dynamic>> filteredCamps = [];
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  final TextEditingController keywordController = TextEditingController();
  final List<String> selectedRegions = [];
  final List<String> selectedTypes = [];
  late final List<String> regionList;
  Map<String, Map<String, dynamic>> availabilityCache = {};

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

    await Future.wait(
      target.map((camp) async {
        final data = await _fetchAvailability(camp['name']);
        if (data != null) availabilityCache[camp['name']] = data;
      }),
    );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Text(
          '금오캠핑',
          style: GoogleFonts.jua(fontSize: 24, color: Colors.black87),
        ),
        iconTheme: IconThemeData(color: Colors.grey.shade600),
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
/// Filter Bar (날짜/지역/숙소 유형/초기화) – 라이트 그레이 + 파스텔 그린
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
    final dateText = DateFormat('yyyy.MM.dd').format(selectedDate);
    final regionLabel =
        selectedRegions.isEmpty
            ? '지역'
            : selectedRegions.length == 1
            ? selectedRegions[0]
            : '${selectedRegions[0]} 외 ${selectedRegions.length - 1}';
    final typeLabel =
        selectedTypes.isEmpty
            ? '유형'
            : selectedTypes.length == 1
            ? selectedTypes[0]
            : '${selectedTypes[0]} 외 ${selectedTypes.length - 1}';

    return Container(
      color: const Color(0xFFDFF3E3), // 파스텔 그린 톤
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _LightButton(
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
                Text(
                  dateText,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey.shade800,
                  size: 16,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _LightButton(
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
                      style: TextStyle(color: Colors.grey.shade800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade800),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _LightButton(
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
                      style: TextStyle(color: Colors.grey.shade800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey.shade800),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(''),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.grey.shade800,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LightButton extends StatelessWidget {
  const _LightButton({required this.child, required this.onPressed});
  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.grey.shade800,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(0, 40),
      ),
      onPressed: onPressed,
      child: child,
    );
  }
}

/// 이하 기존 _MultiSelectSheet, _CampItem, _NoResultWidget, _CampSearchDelegate 구현은 변동 없음

// ─────────────────────────────────────────────────────────────────────────
// 아래 나머지 위젯(_MultiSelectSheet, _CampItem, _NoResultWidget, _CampSearchDelegate)
// 기존 코드와 동일하므로 그대로 복사해 사용해 주세요.
// ─────────────────────────────────────────────────────────────────────────

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
    // 1) 남은 좌석 수에 따른 상태 텍스트·색상 계산
    final statusText =
        available == 0
            ? '예약 마감 ($available/$total)'
            : (available <= 3
                ? '마감 임박 ($available/$total)'
                : '예약 가능 ($available/$total)');
    final statusColor =
        available == 0
            ? Colors.red
            : (available <= 3 ? Colors.orange : Colors.green);
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
                      statusText,
                      style: TextStyle(
                        color: statusColor,
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
                  backgroundColor: available > 0 ? Colors.green : Colors.grey,
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
