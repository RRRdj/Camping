import 'package:flutter/material.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({Key? key}) : super(key: key);

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  // 홈 화면과 동일한 필터 상태
  final Set<String> selectedRegions = {};
  final Set<String> selectedFacilities = {};
  final Set<String> selectedCampTypes = {};

  // 샘플 검색 결과 데이터
  final List<Map<String, dynamic>> searchResults = [
    {
      'location': '경북 구미시',
      'bookmarkCount': 180,
      'name': '파이이씨드',
      'campingname': '지자체 아영장',
      'image': 'assets/images/camp1.jpg',
      'buttonText': '캠핑장 둘러보기',
      'buttonColor': Colors.green,
      'buttonTextColor': Colors.white,
      'isAvailable': true,
    },
    {
      'location': '경북 영주시',
      'bookmarkCount': 150,
      'name': '금호강 산격야영장',
      'campingname': '지자체 아영장',
      'image': 'assets/images/camp2.jpg',
      'buttonText': '캠핑장 둘러보기',
      'buttonColor': Colors.green,
      'buttonTextColor': Colors.white,
      'isAvailable': false,
    },
    {
      'location': '경북 구미시',
      'bookmarkCount': 200,
      'name': '금호강 오토캠핑장',
      'campingname': '국립 아영장',
      'image': 'assets/images/camp3.jpg',
      'buttonText': '빈자리 알림 가능',
      'buttonColor': Colors.orange,
      'buttonTextColor': Colors.white,
      'isAvailable': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('검색 결과'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 검색 입력창
            TextField(
              decoration: const InputDecoration(
                hintText: '검색어를 입력하세요...',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
              onSubmitted: (value) {
                // 검색 로직 구현 (예: API 호출)
              },
            ),
            const SizedBox(height: 16),
            // 상단 선택된 필터 영역 (홈 화면과 동일)
            Wrap(
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
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 하단 필터 버튼 영역 (홈 화면과 동일)
            Row(
              children: [
                _buildMainFilterChip(
                  label: '지역',
                  onTap: () {
                    _showRegionBottomSheet(context);
                  },
                ),
                const SizedBox(width: 8),
                _buildMainFilterChip(
                  label: '부가시설',
                  onTap: () {
                    _showFacilityBottomSheet(context);
                  },
                ),
                const SizedBox(width: 8),
                _buildMainFilterChip(
                  label: '야영장',
                  onTap: () {
                    _showCampTypeBottomSheet(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 검색 결과 개수 표시
            Text(
              '${searchResults.length}개 결과',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            // 검색 결과 목록
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final camp = searchResults[index];
                  return _buildSearchResultItem(camp);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 메인 필터 버튼 위젯 (홈 화면과 동일)
  Widget _buildMainFilterChip({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Chip(
        label: Text(label),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  // 검색 결과 항목 위젯 (홈 화면의 리스트 항목과 동일)
  Widget _buildSearchResultItem(Map<String, dynamic> camp) {
    final location = camp['location'] ?? '지역정보';
    final bookmarkCount = camp['bookmarkCount']?.toString() ?? '0';
    final name = camp['name'] ?? '캠핑장 이름';
    final campType = camp['campingname'] ?? '야영장';
    final imagePath = camp['image'] ?? 'assets/images/camp_default.png';
    final isAvailable = camp['isAvailable'] ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9E5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // 캠핑장 썸네일 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                imagePath,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            // 캠핑장 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 첫 줄: "경북 구미시 ★ 180"
                  Row(
                    children: [
                      Text(
                        location,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, color: Colors.amber, size: 12),
                      Text(
                        ' $bookmarkCount',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 둘째 줄: 캠핑장 이름
                  Text(
                    name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  // 셋째 줄: 야영장 구분 (예: 지자체, 국립)
                  Text(
                    campType,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  // 넷째 줄: 예약 상태 표시
                  Text(
                    isAvailable ? '예약 가능' : '예약 마감',
                    style: TextStyle(
                      fontSize: 13,
                      color: isAvailable ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // 오른쪽 버튼
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: camp['buttonColor'] ?? Colors.green,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                camp['buttonText'] ?? '캠핑장 둘러보기',
                style: TextStyle(
                  fontSize: 12,
                  color: camp['buttonTextColor'] ?? Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 지역 선택 Bottom Sheet
  void _showRegionBottomSheet(BuildContext context) {
    final regionList = [
      '서울', '경기', '강원', '충남/대전',
      '경북', '경남', '전북/전남', '제주'
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '지역 선택',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: regionList.map((region) {
                      final isSelected = selectedRegions.contains(region);
                      return FilterChip(
                        label: Text(region),
                        selected: isSelected,
                        onSelected: (bool value) {
                          setModalState(() {
                            if (value) {
                              selectedRegions.add(region);
                            } else {
                              selectedRegions.remove(region);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {});
                    },
                    child: const Text('선택완료'),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 부가시설 선택 Bottom Sheet
  void _showFacilityBottomSheet(BuildContext context) {
    final facilityList = [
      '전기', '무선인터넷', '장작판매', '온수', '운동시설', '샤워실', '매점'
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '부가시설 선택',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: facilityList.map((facility) {
                      final isSelected = selectedFacilities.contains(facility);
                      return FilterChip(
                        label: Text(facility),
                        selected: isSelected,
                        onSelected: (bool value) {
                          setModalState(() {
                            if (value) {
                              selectedFacilities.add(facility);
                            } else {
                              selectedFacilities.remove(facility);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {});
                    },
                    child: const Text('선택완료'),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 야영장 선택 Bottom Sheet (국립, 지자체)
  void _showCampTypeBottomSheet(BuildContext context) {
    final campTypeList = [
      '국립캠핑장',
      '지자체캠핑장',
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '야영장 선택',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: campTypeList.map((type) {
                      final isSelected = selectedCampTypes.contains(type);
                      return FilterChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (bool value) {
                          setModalState(() {
                            if (value) {
                              selectedCampTypes.add(type);
                            } else {
                              selectedCampTypes.remove(type);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {});
                    },
                    child: const Text('선택완료'),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
