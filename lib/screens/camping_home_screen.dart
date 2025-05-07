import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../campground_data.dart';
import 'camping_info_screen.dart';

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
  static const _serviceKey =
      'aL18yks/TuI52tnTlLaQJMx9YCVO0R+vqXjDZBmBe3ST78itxBjo6ZKJIvlWWSh2tTqkWFpbpELlGrCuKFlUaw==';
  late Future<List<Map<String, dynamic>>> _mergedData;
  Future<List<Map<String, dynamic>>>? _viewData;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  String _kw = '';
  List<String> _reg = [], _type = [], _inDuty = [], _lct = [], _amen = [];
  final _amenities = [
    '전기',
    '무선인터넷',
    '장작판매',
    '온수',
    '트램플린',
    '물놀이장',
    '놀이터',
    '산책로',
    '운동시설',
    '마트.편의점',
  ];
  final _inDutyList = ['글램핑', '캠프닉', '일반야영장', '자동차야영장', '카라반'];
  final _lctClList = ['해변', '섬', '산', '강', '호수', '도심', '숲', '계곡'];
  late final _regionList =
      campgroundList
          .map((c) => c['location'].toString().split(' ').first)
          .toSet()
          .toList()
        ..sort();
  late final _typeList =
      campgroundList.map((c) => c['type'] as String).toSet().toList()..sort();
  late final _allNames =
      campgroundList.map((c) => c['name'] as String).toList()..sort();

  @override
  void initState() {
    super.initState();
    _mergedData = _loadAndMerge();
    _applyAndSearch();
  }

  Future<List<Map<String, dynamic>>> _loadAndMerge() async {
    final uri = Uri.parse(
      'https://apis.data.go.kr/B551011/GoCamping/basedList',
    ).replace(
      queryParameters: {
        'serviceKey': _serviceKey,
        'numOfRows': '5000',
        'pageNo': '1',
        'MobileOS': 'AND',
        'MobileApp': 'camping',
        '_type': 'XML',
      },
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) throw Exception('basedList 실패');
    final doc = xml.XmlDocument.parse(utf8.decode(resp.bodyBytes));
    final temp = <String, Map<String, dynamic>>{};
    for (var n in doc.findAllElements('item')) {
      final name = n.getElement('facltNm')?.text.trim() ?? '';
      if (name.isEmpty) continue;
      temp[name.toLowerCase()] = {
        'contentId': n.getElement('contentId')?.text.trim() ?? '',
        'firstImageUrl': n.getElement('firstImageUrl')?.text.trim() ?? '',
        'amenities':
            (n.getElement('sbrsCl')?.text.trim() ?? '')
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
        'inDuty': n.getElement('induty')?.text.trim() ?? '',
        'lctCl': n.getElement('lctCl')?.text.trim() ?? '',
        'addr1': n.getElement('addr1')?.text.trim() ?? '정보없음',
        'tel': n.getElement('tel')?.text.trim() ?? '정보없음',
        'mapX': n.getElement('mapX')?.text.trim() ?? '0',
        'mapY': n.getElement('mapY')?.text.trim() ?? '0',
        'resveUrl': n.getElement('resveUrl')?.text.trim() ?? '정보없음',
      };
    }
    return [
      for (var c in campgroundList)
        if (temp.containsKey((c['name'] as String).toLowerCase()))
          {...c, ...temp[(c['name'] as String).toLowerCase()]!},
    ];
  }

  void _applyAndSearch() {
    _viewData = _mergedData.then((all) => _sortByAvailability(_filter(all)));
    setState(() {});
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> src) =>
      src.where((c) {
        final nm = (c['name'] as String).toLowerCase();
        if (_kw.isNotEmpty && !nm.contains(_kw.toLowerCase())) return false;
        final region = c['location'].toString().split(' ').first;
        bool inList(List<String> sel, dynamic v) =>
            sel.isEmpty || sel.contains(v);
        if (!inList(_reg, region) ||
            !inList(_type, c['type']) ||
            !inList(_inDuty, c['inDuty']) ||
            !inList(_lct, c['lctCl']))
          return false;
        return _amen.every(
          (a) =>
              _amen.contains(a) ? (c['amenities'] as List).contains(a) : true,
        );
      }).toList();

  Future<List<Map<String, dynamic>>> _sortByAvailability(
    List<Map<String, dynamic>> list,
  ) async {
    final key = DateFormat('yyyy-MM-dd').format(_selectedDate);
    for (var c in list) {
      final d =
          await FirebaseFirestore.instance
              .collection('realtime_availability')
              .doc(c['name'])
              .get();
      final data =
          (d.exists && d.data()!.containsKey(key))
              ? d.data()![key] as Map<String, dynamic>
              : {'available': 0, 'total': 0};
      c['__isAvailable'] = data['available'] > 0;
      c['available'] = data['available'];
      c['total'] = data['total'];
    }
    list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return list;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('금오캠핑'), centerTitle: true),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _viewData,
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('오류: ${snap.error}'));
        final camps = snap.data ?? [];
        return Column(
          children: [
            _HeaderSection(
              selectedDate: _selectedDate,
              onDateChanged: (d) => setState(() => _selectedDate = d),
              filters:
                  (_reg.length +
                      _type.length +
                      _inDuty.length +
                      _lct.length +
                      _amen.length),
              onFilterTap: _showFilterDialog,
              onReset: _resetFilters,
              onSearch: _applyAndSearch,
            ),
            _SearchBar(
              initial: _kw,
              names: _allNames,
              onChanged: (v) => _kw = v,
              onSubmitted: (v) {
                _kw = v;
                _applyAndSearch();
              },
            ),
            Expanded(
              child: _CampsList(
                camps: camps,
                bookmarked: widget.bookmarked,
                onToggleBookmark: widget.onToggleBookmark,
              ),
            ),
          ],
        );
      },
    ),
  );

  void _showFilterDialog() => _showMultiSelectDialog(
    title: '부가시설 선택',
    data: _amenities,
    holder: _amen,
    onConfirm: (sel) => setState(() => _amen = sel),
  );

  void _resetFilters() {
    _kw = '';
    _reg.clear();
    _type.clear();
    _inDuty.clear();
    _lct.clear();
    _amen.clear();
    _applyAndSearch();
  }

  Future<void> _showMultiSelectDialog({
    required String title,
    required List<String> data,
    required List<String> holder,
    required void Function(List<String>) onConfirm,
  }) async {
    final temp = List<String>.from(holder);
    await showDialog(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (_, set2) => AlertDialog(
                  title: Text(title),
                  content: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var v in data)
                          CheckboxListTile(
                            value: temp.contains(v),
                            title: Text(v),
                            onChanged:
                                (b) => set2(
                                  () => b! ? temp.add(v) : temp.remove(v),
                                ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () {
                        onConfirm(temp);
                        Navigator.pop(context);
                      },
                      child: const Text('확인'),
                    ),
                  ],
                ),
          ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final int filters;
  final VoidCallback onFilterTap, onReset, onSearch;
  const _HeaderSection({
    required this.selectedDate,
    required this.onDateChanged,
    required this.filters,
    required this.onFilterTap,
    required this.onReset,
    required this.onSearch,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Row(
      children: [
        TextButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(DateFormat('MM/dd').format(selectedDate)),
          onPressed: () async {
            final p = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime.now().add(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 60)),
            );
            if (p != null) onDateChanged(p);
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ExpansionTile(
            title: const Text('필터 옵션'),
            childrenPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  _FilterButton(
                    label: '부가시설',
                    count: filters,
                    onTap: onFilterTap,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReset,
                      child: const Text('초기화'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onSearch,
                      child: const Text('검색'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SearchBar extends StatelessWidget {
  final String initial;
  final List<String> names;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  const _SearchBar({
    required this.initial,
    required this.names,
    required this.onChanged,
    required this.onSubmitted,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Autocomplete<String>(
      optionsBuilder: (t) {
        final txt = t.text.toLowerCase();
        return txt.isEmpty
            ? const Iterable<String>.empty()
            : names.where((n) => n.toLowerCase().contains(txt));
      },
      fieldViewBuilder: (ctx, ctr, fn, _) {
        ctr.text = initial;
        return TextField(
          controller: ctr,
          focusNode: fn,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: '캠핑장 이름 검색',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
      onSelected: onSubmitted,
    ),
  );
}

class _CampsList extends StatelessWidget {
  final List<Map<String, dynamic>> camps;
  final Map<String, bool> bookmarked;
  final void Function(String) onToggleBookmark;
  const _CampsList({
    required this.camps,
    required this.bookmarked,
    required this.onToggleBookmark,
  });
  @override
  Widget build(BuildContext context) =>
      camps.isEmpty
          ? const Center(child: Text('검색 결과가 없습니다.'))
          : ListView.builder(
            itemCount: camps.length,
            itemBuilder:
                (c, i) => _CampCard(
                  camp: camps[i],
                  isBookmarked: bookmarked[camps[i]['name']] == true,
                  onToggleBookmark: onToggleBookmark,
                ),
          );
}

class _CampCard extends StatelessWidget {
  final Map<String, dynamic> camp;
  final bool isBookmarked;
  final void Function(String) onToggleBookmark;
  const _CampCard({
    required this.camp,
    required this.isBookmarked,
    required this.onToggleBookmark,
  });
  @override
  Widget build(BuildContext context) {
    final isAvail = camp['__isAvailable'] as bool? ?? false;
    final avail = camp['available'] as int? ?? 0;
    final tot = camp['total'] as int? ?? 0;
    return Opacity(
      opacity: isAvail ? 1 : 0.4,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CampingInfoScreen(camp: camp)),
            ),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if ((camp['firstImageUrl'] as String?)?.isNotEmpty ?? false)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      camp['firstImageUrl'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const Icon(Icons.park, size: 48, color: Colors.teal),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camp['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${camp['location']} | ${camp['type']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isAvail ? '예약 가능 ($avail/$tot)' : '예약 마감 ($avail/$tot)',
                        style: TextStyle(
                          color: isAvail ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.favorite : Icons.favorite_border,
                    color: isBookmarked ? Colors.red : Colors.grey,
                  ),
                  onPressed: () => onToggleBookmark(camp['name']),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTap;
  const _FilterButton({
    required this.label,
    required this.count,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 100,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(count == 0 ? label : '$count개'),
    ),
  );
}
