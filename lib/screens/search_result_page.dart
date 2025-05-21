import 'package:flutter/material.dart';
import 'package:camping/repositories/search_repository.dart';
import 'package:camping/services/search_display_service.dart';
import 'package:camping/services/static_data_service.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({Key? key}) : super(key: key);

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  final _repo = SearchRepository();
  final _display = SearchDisplayService();
  final _keywordCtrl = TextEditingController();
  bool _loading = false;

  /* 필터 상태 */
  final Set<String> selectedRegions = {};
  final Set<String> selectedFacilities = {};
  final Set<String> selectedCampTypes = {};

  /* 검색 결과 */
  List<Map<String, dynamic>> searchResults = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('검색 결과'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _keywordCtrl,
              decoration: const InputDecoration(
                hintText: '검색어를 입력하세요...',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 16),
            _buildSelectedFilterChips(),
            const SizedBox(height: 8),
            _buildMainFilterButtons(),
            const SizedBox(height: 8),
            Text(
              '${searchResults.length}개 결과',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder:
                            (_, i) => _buildSearchResultItem(searchResults[i]),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /* -------------- 검색 실행 -------------- */
  Future<void> _performSearch() async {
    setState(() => _loading = true);
    final results = await _repo.search(
      keyword: _keywordCtrl.text.trim(),
      regions: selectedRegions,
      facilities: selectedFacilities,
      campTypes: selectedCampTypes,
    );
    setState(() {
      searchResults = results;
      _loading = false;
    });
  }

  /* -------------- 필터 UI -------------- */
  Widget _buildSelectedFilterChips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      if (selectedRegions.isNotEmpty)
        Chip(
          label: Text('지역: ${selectedRegions.join(', ')}'),
          backgroundColor: Colors.teal.shade100,
        ),
      if (selectedFacilities.isNotEmpty)
        Chip(
          label: Text('부가시설: ${selectedFacilities.join(', ')}'),
          backgroundColor: Colors.teal.shade100,
        ),
      if (selectedCampTypes.isNotEmpty)
        Chip(
          label: Text('야영장: ${selectedCampTypes.join(', ')}'),
          backgroundColor: Colors.teal.shade100,
        ),
      if (selectedRegions.isNotEmpty ||
          selectedFacilities.isNotEmpty ||
          selectedCampTypes.isNotEmpty)
        ActionChip(
          label: const Text('초기화', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.teal,
          onPressed: () {
            setState(() {
              selectedRegions.clear();
              selectedFacilities.clear();
              selectedCampTypes.clear();
            });
            _performSearch();
          },
        ),
    ],
  );

  Widget _buildMainFilterButtons() => Row(
    children: [
      _buildMainFilterChip(
        label: '지역',
        onTap:
            () => _showBottomSheet(
              title: '지역 선택',
              items: StaticDataService.regions,
              selected: selectedRegions,
            ),
      ),
      const SizedBox(width: 8),
      _buildMainFilterChip(
        label: '부가시설',
        onTap:
            () => _showBottomSheet(
              title: '부가시설 선택',
              items: StaticDataService.facilities,
              selected: selectedFacilities,
            ),
      ),
      const SizedBox(width: 8),
      _buildMainFilterChip(
        label: '야영장',
        onTap:
            () => _showBottomSheet(
              title: '야영장 선택',
              items: StaticDataService.campTypes,
              selected: selectedCampTypes,
            ),
      ),
    ],
  );

  Widget _buildMainFilterChip({
    required String label,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    child: Chip(
      label: Text(label),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: Colors.grey.shade300),
    ),
  );

  /* 재사용 BottomSheet */
  void _showBottomSheet({
    required String title,
    required List<String> items,
    required Set<String> selected,
  }) {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (ctx, setModal) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            items
                                .map(
                                  (e) => FilterChip(
                                    label: Text(e),
                                    selected: selected.contains(e),
                                    onSelected:
                                        (v) => setModal(
                                          () =>
                                              v
                                                  ? selected.add(e)
                                                  : selected.remove(e),
                                        ),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _performSearch();
                        },
                        child: const Text('선택완료'),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  /* -------------- 카드 UI -------------- */
  Widget _buildSearchResultItem(Map<String, dynamic> camp) {
    final d = _display.parse(camp);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                d.imagePath,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(d.location, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, color: Colors.amber, size: 12),
                      Text(
                        ' ${d.bookmarkCount}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.campType,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.isAvailable ? '예약 가능' : '예약 마감',
                    style: TextStyle(
                      fontSize: 13,
                      color: d.isAvailable ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: d.buttonColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                d.buttonText,
                style: TextStyle(fontSize: 12, color: d.buttonTextColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
