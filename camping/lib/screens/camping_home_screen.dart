// lib/screens/camping_home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'camping_info_screen.dart';

class CampingHomeScreen extends StatefulWidget {
  final Map<String, bool> bookmarked;
  final void Function(String name) onToggleBookmark;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const CampingHomeScreen({
    Key? key,
    required this.bookmarked,
    required this.onToggleBookmark,
    required this.selectedDate,
    required this.onDateChanged,

  }) : super(key: key);

  @override
  State<CampingHomeScreen> createState() => _CampingHomeScreenState();
}

class _CampingHomeScreenState extends State<CampingHomeScreen> {
  //DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _appliedKeyword;
  String? _appliedRegion;
  String? _appliedType;
  String? _appliedDuty;
  String? _appliedEnv;
  String? _appliedAmenity;

  List<Map<String, dynamic>> _camps = [];

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('campgrounds')
        .snapshots()
        .listen((snap) {
      setState(() {
        _camps = snap.docs
            .map((d) => d.data()! as Map<String, dynamic>)
            .toList();
      });
    });
  }

  void _openFilterSheet() {
    final regions = _camps
        .map((c) => (c['location'] as String).split(' ').first)
        .toSet()
        .toList()
      ..sort();
    final types = _camps.map((c) => c['type'] as String).toSet().toList()
      ..sort();
    final duties = _camps
        .expand((c) => (c['inDuty'] as String? ?? '')
        .split(',')
        .where((s) => s.isNotEmpty))
        .toSet()
        .toList()
      ..sort();
    final envs = _camps
        .map((c) => c['lctCl'] as String? ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final amenities = _camps
        .expand((c) => (c['amenities'] as List<dynamic>? ?? []))
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          builder: (_, controller) => StatefulBuilder(
            builder: (ctx2, setModalState) => SingleChildScrollView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text('검색 필터',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: '지역',
                    options: regions,
                    value: _appliedRegion,
                    onSelected: (v) => setModalState(() => _appliedRegion = v),
                  ),
                  _buildSection(
                    title: '캠핑장 유형',
                    options: types,
                    value: _appliedType,
                    onSelected: (v) => setModalState(() => _appliedType = v),
                  ),
                  _buildSection(
                    title: '야영장 구분',
                    options: duties,
                    value: _appliedDuty,
                    onSelected: (v) => setModalState(() => _appliedDuty = v),
                  ),
                  _buildSection(
                    title: '환경',
                    options: envs,
                    value: _appliedEnv,
                    onSelected: (v) => setModalState(() => _appliedEnv = v),
                  ),
                  _buildSection(
                    title: '편의시설',
                    options: amenities,
                    value: _appliedAmenity,
                    onSelected: (v) =>
                        setModalState(() => _appliedAmenity = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, color: Colors.teal),
                        label: const Text('초기화',
                            style: TextStyle(color: Colors.teal)),
                        onPressed: () => setModalState(() {
                          _appliedKeyword = null;
                          _appliedRegion = null;
                          _appliedType = null;
                          _appliedDuty = null;
                          _appliedEnv = null;
                          _appliedAmenity = null;
                        }),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(ctx);
                        },
                        child: const Text('적용',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<String> options,
    required String? value,
    required void Function(String?) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final selected = opt == value;
            return ChoiceChip(
              label: Text(opt),
              selected: selected,
              onSelected: (_) => onSelected(selected ? null : opt),
              selectedColor: Colors.teal.shade100,
              backgroundColor: Colors.grey.shade200,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('MM월 dd일').format(widget.selectedDate);
    final dateKey   = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('캠핑장 목록'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: GestureDetector(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: widget.selectedDate,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 14)),
                );
                if (picked != null) widget.onDateChanged(picked);
              },
              child: Chip(
                avatar:
                const Icon(Icons.calendar_today, color: Colors.white),
                label: Text(dateLabel,
                    style: const TextStyle(color: Colors.white)),
                backgroundColor: Colors.teal,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: '검색어를 입력하세요',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _appliedKeyword = v),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('campgrounds')
                  .snapshots(),
              builder: (ctx, campSnap) {
                if (!campSnap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final camps = campSnap.data!.docs
                    .map((d) => d.data()! as Map<String, dynamic>)
                    .toList();

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('realtime_availability')
                      .snapshots(),
                  builder: (ctx2, availSnap) {
                    if (!availSnap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final availabilityMap = <String, Map<String, dynamic>>{};
                    for (var doc in availSnap.data!.docs) {
                      availabilityMap[doc.id] =
                      doc.data()! as Map<String, dynamic>;
                    }

                    final filtered = camps.where((c) {
                      final name = (c['name'] as String).toLowerCase();
                      if (_appliedKeyword != null &&
                          _appliedKeyword!.isNotEmpty &&
                          !name.contains(_appliedKeyword!.toLowerCase())) {
                        return false;
                      }
                      if (_appliedRegion != null &&
                          (c['location'] as String)
                              .split(' ')
                              .first !=
                              _appliedRegion) {
                        return false;
                      }
                      if (_appliedType != null && c['type'] != _appliedType) {
                        return false;
                      }
                      if (_appliedDuty != null) {
                        final duties = (c['inDuty'] as String? ?? '')
                            .split(',')
                            .where((s) => s.isNotEmpty);
                        if (!duties.contains(_appliedDuty)) {
                          return false;
                        }
                      }
                      if (_appliedEnv != null &&
                          (c['lctCl'] as String? ?? '') != _appliedEnv) {
                        return false;
                      }
                      if (_appliedAmenity != null &&
                          !((c['amenities'] as List<dynamic>? ?? [])
                              .contains(_appliedAmenity))) {
                        return false;
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('검색결과가 없습니다',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey)),
                      );
                    }

                    filtered.sort((a, b) {
                      final aAv = availabilityMap[a['name']]?[dateKey]
                      ?['available'] as int? ??
                          (a['available'] as int? ?? 0);
                      final bAv = availabilityMap[b['name']]?[dateKey]
                      ?['available'] as int? ??
                          (b['available'] as int? ?? 0);
                      return bAv.compareTo(aAv);
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx4, i) {
                        final c = filtered[i];
                        final aMap = availabilityMap[c['name']]?[dateKey]
                        as Map<String, dynamic>?;
                        final avail = aMap?['available'] as int? ??
                            (c['available'] as int? ?? 0);
                        final total = aMap?['total'] as int? ??
                            (c['total'] as int? ?? 0);
                        final isAvail = avail > 0;

                        return Opacity(
                          opacity: isAvail ? 1 : 0.4,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CampingInfoScreen(
                                  campName: c['name'],
                                  available: avail,
                                  total: total,
                                  isBookmarked:
                                  widget.bookmarked[c['name']] ==
                                      true,
                                  onToggleBookmark:
                                  widget.onToggleBookmark,
                                  selectedDate: widget.selectedDate,
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
                                    if (c['firstImageUrl'] != null &&
                                        (c['firstImageUrl'] as String)
                                            .isNotEmpty)
                                      ClipRRect(
                                        borderRadius:
                                        BorderRadius.circular(8),
                                        child: Image.network(
                                          c['firstImageUrl'],
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
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(c['name'],
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                  FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${c['location']} | ${c['type']}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            isAvail
                                                ? '예약 가능 ($avail/$total)'
                                                : '예약 마감 ($avail/$total)',
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
                                        (widget.bookmarked[c['name']] ??
                                            false)
                                            ? Icons.bookmark
                                            : Icons.bookmark_border,
                                        color: (widget.bookmarked[
                                        c['name']] ??
                                            false)
                                            ? Colors.red
                                            : Colors.grey,
                                      ),
                                      onPressed: () =>
                                          widget.onToggleBookmark(
                                              c['name']),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
