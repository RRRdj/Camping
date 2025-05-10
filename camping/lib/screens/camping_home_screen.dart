// lib/screens/camping_home_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../campground_data.dart';
import 'camping_info_screen.dart';

class CampingHomeScreen extends StatefulWidget {
  final Map<String, bool> bookmarked;
  final void Function(String name) onToggleBookmark;

  const CampingHomeScreen({
    Key? key,
    required this.bookmarked,
    required this.onToggleBookmark,
  }) : super(key: key);

  @override
  State<CampingHomeScreen> createState() => _CampingHomeScreenState();
}

class _CampingHomeScreenState extends State<CampingHomeScreen> {
  static const _serviceKey = 'aL18yks/TuI52tnTlLaQJMx9YCVO0R+vqXjDZBmBe3ST78itxBjo6ZKJIvlWWSh2tTqkWFpbpELlGrCuKFlUaw==';

  late Future<List<Map<String, dynamic>>> _mergedDataFuture;
  Future<List<Map<String, dynamic>>>? _filteredSortedFuture;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));

  // 필터 입력값
  String _inputKeyword = '';
  String? _inputRegion;
  String? _inputType;
  String? _inputInDuty;
  String? _inputLctCl;
  List<String> _inputAmenities = [];

  // 적용된 필터
  String _appliedKeyword = '';
  String? _appliedRegion;
  String? _appliedType;
  String? _appliedInDuty;
  String? _appliedLctCl;
  List<String> _appliedAmenities = [];

  // 옵션 목록
  final List<String> _amenities = [
    '전기','무선인터넷','장작판매','온수','트램플린',
    '물놀이장','놀이터','산책로','운동시설','마트.편의점',
  ];
  final List<String> _inDutyList = ['글램핑','캠프닉','일반야영장','자동차야영장','카라반'];
  final List<String> _lctClList  = ['해변','섬','산','강','호수','도심','숲','계곡'];

  // campground_data.dart 로부터 추출
  late final List<String> _regionList = campgroundList
      .map((c) => c['location'].toString().split(' ').first)
      .toSet().toList()..sort();
  late final List<String> _typeList = campgroundList
      .map((c) => c['type'] as String).toSet().toList()..sort();
  late final List<String> _allNames = campgroundList
      .map((c) => c['name'] as String).toList()..sort();

  @override
  void initState() {
    super.initState();
    _mergedDataFuture = _loadAndMergeData();
    _performSearch();
  }

  void _performSearch() {
    _filteredSortedFuture = _mergedDataFuture.then((merged) {
      final f = _applyFilters(merged);
      return _sortByAvailability(f);
    });
    setState(() {});
  }

  void _resetAll() {
    setState(() {
      _selectedDate = DateTime.now().add(const Duration(days: 1));
      _inputKeyword = '';
      _inputRegion = null;
      _inputType = null;
      _inputInDuty = null;
      _inputLctCl = null;
      _inputAmenities = [];
      _appliedKeyword = '';
      _appliedRegion = null;
      _appliedType = null;
      _appliedInDuty = null;
      _appliedLctCl = null;
      _appliedAmenities = [];
    });
    _performSearch();
  }

  Future<void> _showAmenitiesDialog() async {
    final temp = List<String>.from(_inputAmenities);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState2) => AlertDialog(
          title: const Text('부가시설 선택'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _amenities.map((am) {
                final checked = temp.contains(am);
                return CheckboxListTile(
                  title: Text(am),
                  value: checked,
                  onChanged: (v) => setState2(() {
                    if (v == true) temp.add(am);
                    else temp.remove(am);
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(
              onPressed: () {
                setState(() => _inputAmenities = temp);
                Navigator.pop(ctx);
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadAndMergeData() async {
    final resp = await http.get(
      Uri.parse('https://apis.data.go.kr/B551011/GoCamping/basedList')
          .replace(queryParameters: {
        'serviceKey': _serviceKey,
        'numOfRows': '5000',
        'pageNo': '1',
        'MobileOS': 'AND',
        'MobileApp': 'camping',
        '_type': 'XML',
      }),
    );
    if (resp.statusCode != 200) throw Exception('API 오류 ${resp.statusCode}');
    final doc = XmlDocument.parse(utf8.decode(resp.bodyBytes));

    final items = <String, Map<String, dynamic>>{};
    for (var node in doc.findAllElements('item')) {
      final name = node.getElement('facltNm')?.text.trim() ?? '';
      if (name.isEmpty) continue;
      items[name.toLowerCase()] = {
        'contentId': node.getElement('contentId')?.text.trim() ?? '',
        'firstImageUrl': node.getElement('firstImageUrl')?.text.trim() ?? '',
        'amenities': (node.getElement('sbrsCl')?.text.trim() ?? '')
            .split(',').map((s) => s.trim()).where((s)=>s.isNotEmpty).toList(),
        'inDuty': node.getElement('induty')?.text.trim() ?? '',
        'lctCl': node.getElement('lctCl')?.text.trim() ?? '',
        'addr1': node.getElement('addr1')?.text.trim() ?? '정보없음',
        'tel': node.getElement('tel')?.text.trim() ?? '정보없음',
        'mapX': node.getElement('mapX')?.text.trim() ?? '0',
        'mapY': node.getElement('mapY')?.text.trim() ?? '0',
        'resveUrl': node.getElement('resveUrl')?.text.trim() ?? '정보없음',
      };
    }

    final merged = <Map<String, dynamic>>[];
    for (var camp in campgroundList) {
      final key = (camp['name'] as String).toLowerCase();
      if (!items.containsKey(key)) continue;
      merged.add({...camp, ...items[key]!});
    }
    return merged;
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> list) =>
      list.where((camp) {
        final nm = (camp['name'] as String).toLowerCase();
        if (_appliedKeyword.isNotEmpty &&
            !nm.contains(_appliedKeyword.toLowerCase())) return false;
        if (_appliedRegion != null &&
            camp['location'].toString().split(' ').first != _appliedRegion)
          return false;
        if (_appliedType != null && camp['type'] != _appliedType) return false;
        if (_appliedInDuty != null && camp['inDuty'] != _appliedInDuty)
          return false;
        if (_appliedLctCl != null && camp['lctCl'] != _appliedLctCl)
          return false;
        for (var am in _appliedAmenities) {
          if (!(camp['amenities'] as List<String>).contains(am)) return false;
        }
        return true;
      }).toList();

  Future<List<Map<String, dynamic>>> _sortByAvailability(
      List<Map<String, dynamic>> list) async {
    final key = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final out = <Map<String, dynamic>>[];
    for (var camp in list) {
      final doc = await FirebaseFirestore.instance
          .collection('realtime_availability')
          .doc(camp['name'].toString())
          .get();
      final avail = (doc.exists && doc.data()!.containsKey(key))
          ? doc.data()![key]['available'] as int
          : 0;
      camp['__isAvailable'] = avail > 0;
      camp['available'] = avail;
      camp['total'] = (doc.exists && doc.data()!.containsKey(key))
          ? doc.data()![key]['total'] as int
          : 0;
      out.add(camp);
    }
    out.sort((a, b) =>
    (b['__isAvailable'] as bool ? 1 : 0) - (a['__isAvailable'] as bool ? 1 : 0));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('금오캠핑'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _filteredSortedFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('오류: ${snap.error}'));
          final camps = snap.data!;

          return Column(
            children: [
              // 검색창
              Padding(
                padding: const EdgeInsets.all(16),
                child: Autocomplete<String>(
                  optionsBuilder: (txt) {
                    final t = txt.text.toLowerCase();
                    return t.isEmpty
                        ? const []
                        : _allNames.where((n) =>
                        n.toLowerCase().contains(t));
                  },
                  fieldViewBuilder: (ctx, ctr, fn, onSubmit) {
                    ctr.text = _inputKeyword;
                    return TextField(
                      controller: ctr,
                      focusNode: fn,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (v) {
                        setState(() {
                          _inputKeyword = v;
                          _appliedKeyword = v;
                        });
                        _performSearch();
                      },
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
                      onChanged: (v) => _inputKeyword = v,
                    );
                  },
                  onSelected: (sel) {
                    _inputKeyword = sel;
                    _appliedKeyword = sel;
                    _performSearch();
                  },
                ),
              ),

              // 날짜 선택 버튼 (필터 밖으로 이동)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton.icon(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate:
                      DateTime.now().add(const Duration(days: 1)),
                      lastDate:
                      DateTime.now().add(const Duration(days: 5)),
                    );
                    if (p != null) {
                      setState(() => _selectedDate = p);
                      _performSearch();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('MM/dd').format(_selectedDate)),
                ),
              ),

              // 필터 옵션 (ExpansionTile 안에서는 날짜 선택 제거됨)
              ExpansionTile(
                title: const Text('필터 옵션'),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDropdown('지역', _inputRegion,
                          [null, ..._regionList],
                              (v) => setState(() => _inputRegion = v)),
                      _buildDropdown('유형', _inputType,
                          [null, ..._typeList],
                              (v) => setState(() => _inputType = v)),
                      _buildDropdown('형태', _inputInDuty,
                          [null, ..._inDutyList],
                              (v) => setState(() => _inputInDuty = v)),
                      _buildDropdown('환경', _inputLctCl,
                          [null, ..._lctClList],
                              (v) => setState(() => _inputLctCl = v)),
                      SizedBox(
                        width: 100,
                        child: TextButton(
                          onPressed: _showAmenitiesDialog,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(_inputAmenities.isEmpty
                              ? '부가시설'
                              : '${_inputAmenities.length}개'),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _resetAll,
                            child: const Text('초기화'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _appliedKeyword = _inputKeyword;
                              _appliedRegion = _inputRegion;
                              _appliedType = _inputType;
                              _appliedInDuty = _inputInDuty;
                              _appliedLctCl = _inputLctCl;
                              _appliedAmenities = List.from(_inputAmenities);
                              _performSearch();
                            },
                            child: const Text('검색'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 결과 리스트
              Expanded(
                child: camps.isEmpty
                    ? const Center(child: Text('검색 결과가 없습니다.'))
                    : ListView.builder(
                  itemCount: camps.length,
                  itemBuilder: (_, i) {
                    final camp = camps[i];
                    final firstUrl = camp['firstImageUrl'] as String?;
                    final hasImage = (firstUrl?.isNotEmpty ?? false);
                    final isAvail = camp['__isAvailable'] as bool? ?? false;
                    final avail = camp['available'] as int? ?? 0;
                    final tot = camp['total'] as int? ?? 0;

                    return Opacity(
                      opacity: isAvail ? 1 : 0.4,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CampingInfoScreen(
                              campName:  camp['name'] as String,
                              available: camp['available'] as int? ?? 0,  // ← 여기
                              total:     camp['total']     as int? ?? 0,  // ← 여기
                              isBookmarked: widget.bookmarked[camp['name'] as String] == true,
                              onToggleBookmark: widget.onToggleBookmark,
                            ),
                          ),
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                if (hasImage)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      firstUrl!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                else
                                  const Icon(Icons.park,
                                      size: 48, color: Colors.teal),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        camp['name'] as String,
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
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        isAvail
                                            ? '예약 가능 ($avail/$tot)'
                                            : '예약 마감 ($avail/$tot)',
                                        style: TextStyle(
                                          color: isAvail
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    widget.bookmarked[camp['name'] as String] == true
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: widget.bookmarked[camp['name'] as String] == true
                                        ? Colors.red
                                        : Colors.grey,
                                  ),
                                  onPressed: () =>
                                      widget.onToggleBookmark(camp['name'] as String),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDropdown<T>(
      String hint,
      T? value,
      List<T?> items,
      void Function(T?) onChanged,
      ) {
    return SizedBox(
      width: 100,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<T?>(
          isExpanded: true,
          value: value,
          underline: const SizedBox(),
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(hint),
          ),
          items: items.map((it) {
            return DropdownMenuItem<T?>(
              value: it,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(it?.toString() ?? hint),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
