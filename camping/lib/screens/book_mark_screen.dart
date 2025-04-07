import 'package:flutter/material.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({Key? key}) : super(key: key);

  // 북마크된 캠핑장 샘플 데이터
  final List<Map<String, dynamic>> bookmarkedCampingList = const [
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
      'location': '경북 구미시',
      'bookmarkCount': 150,
      'name': '금호강 산격야영장',
      'campingname': '지자체 아영장',
      'image': 'assets/images/camp2.jpg',
      'buttonText': '캠핑장 둘러보기',
      'buttonColor': Colors.green,
      'buttonTextColor': Colors.white,
      'isAvailable': true,
    },
    {
      'location': '경북 영주시',
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
        title: const Text('북마크'),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: bookmarkedCampingList.length,
        itemBuilder: (context, index) {
          final camp = bookmarkedCampingList[index];
          return _buildBookmarkedCampItem(context, camp);
        },
      ),
    );
  }

  Widget _buildBookmarkedCampItem(BuildContext context, Map<String, dynamic> camp) {
    final location = camp['location'] ?? '지역정보';
    final bookmarkCount = camp['bookmarkCount']?.toString() ?? '0';
    final name = camp['name'] ?? '캠핑장 이름';
    final campType = camp['campingname'] ?? '야영장';
    final imagePath = camp['image'] ?? 'assets/images/camp_default.png';
    final isAvailable = camp['isAvailable'] ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
}
