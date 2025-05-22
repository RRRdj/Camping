import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/campground_repository.dart';
import '../services/camping_filter_service.dart';
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
  final _repo = CampgroundRepository();
  final _service = CampingFilterService();

  /* ── 현재 선택된 필터 값 ── */
  String? _keyword, _region, _type, _duty, _env, _amenity;

  /* ── 필터 BottomSheet ── */
  void _openFilterSheet(List<Map<String, dynamic>> camps) {
    final regions = _service.regions(camps);
    final types = _service.types(camps);
    final duties = _service.duties(camps);
    final envs = _service.envs(camps);
    final amenities = _service.amenities(camps);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => SafeArea(
            top: false,
            child: DraggableScrollableSheet(
              expand: false,
              builder:
                  (_, controller) => StatefulBuilder(
                    builder:
                        (_, setModal) => SingleChildScrollView(
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
                                child: Text(
                                  '검색 필터',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _chipSection(
                                '지역',
                                regions,
                                _region,
                                (v) => setModal(() => _region = v),
                              ),
                              _chipSection(
                                '캠핑장 유형',
                                types,
                                _type,
                                (v) => setModal(() => _type = v),
                              ),
                              _chipSection(
                                '야영장 구분',
                                duties,
                                _duty,
                                (v) => setModal(() => _duty = v),
                              ),
                              _chipSection(
                                '환경',
                                envs,
                                _env,
                                (v) => setModal(() => _env = v),
                              ),
                              _chipSection(
                                '편의시설',
                                amenities,
                                _amenity,
                                (v) => setModal(() => _amenity = v),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.refresh,
                                      color: Colors.teal,
                                    ),
                                    label: const Text(
                                      '초기화',
                                      style: TextStyle(color: Colors.teal),
                                    ),
                                    onPressed:
                                        () => setModal(() {
                                          _keyword =
                                              _region =
                                                  _type =
                                                      _duty =
                                                          _env =
                                                              _amenity = null;
                                        }),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {}); // 필터 적용
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text(
                                      '적용',
                                      style: TextStyle(color: Colors.white),
                                    ),
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

  /* ── Chip Builder ── */
  Widget _chipSection(
    String title,
    List<String> opts,
    String? val,
    ValueChanged<String?> onSel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              opts
                  .map(
                    (o) => ChoiceChip(
                      label: Text(o),
                      selected: o == val,
                      onSelected: (_) => onSel(o == val ? null : o),
                      selectedColor: Colors.teal.shade100,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /* ── UI ── */
  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('MM월 dd일').format(widget.selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('캠핑장 목록'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _repo.watchCamps().first.then(_openFilterSheet),
          ),
        ],
      ),
      body: Column(
        children: [
          /* 날짜 Chip */
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
                avatar: const Icon(Icons.calendar_today, color: Colors.white),
                label: Text(
                  dateLabel,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.teal,
              ),
            ),
          ),
          /* 검색어 입력 */
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
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
          /* 데이터 스트림 */
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _repo.watchCamps(),
              builder: (_, campSnap) {
                if (!campSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StreamBuilder<Map<String, Map<String, dynamic>>>(
                  stream: _repo.watchAvailability(),
                  builder: (_, avSnap) {
                    if (!avSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final filtered = _service.apply(
                      camps: campSnap.data!,
                      availability: avSnap.data!,
                      date: widget.selectedDate,
                      keyword: _keyword,
                      region: _region,
                      type: _type,
                      duty: _duty,
                      env: _env,
                      amenity: _amenity,
                    );

                    final sorted = List<Map<String, dynamic>>.from(
                      filtered,
                    )..sort(
                      (a, b) =>
                          a['name'].toString().compareTo(b['name'].toString()),
                    );

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          '검색결과가 없습니다',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    final dateKey = DateFormat(
                      'yyyy-MM-dd',
                    ).format(widget.selectedDate);

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: sorted.length,
                      itemBuilder: (_, i) {
                        final c = sorted[i];
                        final a =
                            avSnap.data![c['name']]?[dateKey]
                                as Map<String, dynamic>?;

                        final avail =
                            a?['available'] as int? ?? (c['available'] ?? 0);
                        final total = a?['total'] as int? ?? (c['total'] ?? 0);
                        final open = avail > 0;

                        return Opacity(
                          opacity: open ? 1 : 0.4,
                          child: InkWell(
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => CampingInfoScreen(
                                          campName: c['name'],
                                          available: avail,
                                          total: total,
                                          isBookmarked:
                                              widget.bookmarked[c['name']] ??
                                              false,
                                          onToggleBookmark:
                                              widget.onToggleBookmark,
                                          selectedDate: widget.selectedDate,
                                        ),
                                  ),
                                ),
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    (c['firstImageUrl'] as String?)
                                                ?.isNotEmpty ??
                                            false
                                        ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            c['firstImageUrl'],
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.park,
                                          size: 48,
                                          color: Colors.teal,
                                        ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c['name'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${c['location']} | ${c['type']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            open
                                                ? '예약 가능 ($avail/$total)'
                                                : '예약 마감 ($avail/$total)',
                                            style: TextStyle(
                                              color:
                                                  open
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
                                        (widget.bookmarked[c['name']] ?? false)
                                            ? Icons.bookmark
                                            : Icons.bookmark_border,
                                        color:
                                            (widget.bookmarked[c['name']] ??
                                                    false)
                                                ? Colors.red
                                                : Colors.grey,
                                      ),
                                      onPressed:
                                          () => widget.onToggleBookmark(
                                            c['name'],
                                          ),
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
