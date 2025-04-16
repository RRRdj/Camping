import 'package:flutter/material.dart';

class RegionSelectionScreen extends StatelessWidget {
  final List<String> regions = [
    "서울", "인천", "경기", "강원",
    "충남/대전", "충북", "경남", "경북",
    "대구", "전남/광주", "전북", "제주"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단/하단 여백을 좀 더 주기 위해 SafeArea나 Padding 사용
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
          child: Column(
            children: [
              // 상단 타이틀
              Text(
                "금오캠핑 (가제)",
                style: TextStyle(
                  fontSize: 24,  // 글자 크기 키움
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "지역을 선택해주세요",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 30),

              // 지역 선택 그리드
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  // 블록들 사이 간격
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  // 가로:세로 비율 (숫자가 클수록 가로가 넓어짐)
                  childAspectRatio: 2.7,
                  shrinkWrap: true,
                  children: regions.map((region) {
                    return _buildRegionButton(context, region);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegionButton(BuildContext context, String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(15),
      ),
      // 버튼 전체를 가운데 정렬
      child: Center(
        child: TextButton(
          onPressed: () {
            if (text == "경북") {
              Navigator.pushNamed(context, '/camping_sites_page');
            } else {
              Navigator.pushNamed(context, '/detail', arguments: text);
            }
          },
          child: Text(
            text,
            style: TextStyle(color: Colors.black, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
