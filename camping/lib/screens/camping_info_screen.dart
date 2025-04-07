import 'package:flutter/material.dart';

class CampingInfoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('구미 캠핑장'),
        leading: BackButton(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 정보
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '주소: 경상북도 구미시 낙동제방길 200\n지원유무: 전기/무선인터넷/온수/장작판매\n홈페이지: https://www.gmuc.or.kr/camping/index.do',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                Column(
                  children: [
                    Icon(Icons.star_border),
                    SizedBox(height: 8),
                    // content_copy 아이콘을 IconButton으로 변경하여 '/memo'로 이동
                    IconButton(
                      icon: Icon(Icons.content_copy),
                      onPressed: () {
                        Navigator.pushNamed(context, '/memo');
                      },
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            // 예약 현황 버튼
            ElevatedButton(
              onPressed: () {
                // 예약 현황 버튼 누르면 detail_screen.dart로 이동 (인자로 '구미' 전달)
                Navigator.pushNamed(context, '/detail', arguments: '구미');
              },
              child: Text('예약 현황'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
              ),
            ),
            SizedBox(height: 24),
            Text('사진', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            // 사진 영역
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/camp1.jpg',
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/camp2.jpg',
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 후기 작성 버튼 누르면 review 화면으로 이동
                Navigator.pushNamed(context, '/review');
              },
              child: Text('후기 작성'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 40),
              ),
            ),
            SizedBox(height: 24),
            Text('후기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            // 후기 리스트 예시
            _buildReview(
              name: '익명',
              date: '2025-03-24',
              rating: 5,
              content: '캠핑장이 정말 깨끗하고 시설이 좋아요.',
            ),
            _buildReview(
              name: '김철수',
              date: '2025-03-26',
              rating: 4,
              content: '주차 공간이 넓고 편리했어요.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReview({required String name, required String date, required int rating, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
        Text(date, style: TextStyle(color: Colors.black)),
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: Colors.green,
              size: 20,
            );
          }),
        ),
        Text(content),
        SizedBox(height: 16),
      ],
    );
  }
}
