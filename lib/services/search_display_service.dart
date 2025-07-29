import 'package:flutter/material.dart';

class SearchDisplayService {
  /// 캠핑장 raw Map → 카드에 필요한 값들 변환
  SearchCardData parse(Map<String, dynamic> m) => SearchCardData(
    location: m['location'] ?? '지역정보',
    bookmarkCount: (m['bookmarkCount'] ?? 0).toString(),
    name: m['name'] ?? '캠핑장 이름',
    campType: m['campingname'] ?? '야영장',
    imagePath: m['image'] ?? 'assets/images/camp_default.png',
    isAvailable: m['isAvailable'] ?? true,
    buttonText: m['buttonText'] ?? '캠핑장 둘러보기',
    buttonColor: (m['buttonColor'] as Color?) ?? Colors.green,
    buttonTextColor: (m['buttonTextColor'] as Color?) ?? Colors.white,
  );
}

class SearchCardData {
  final String location, bookmarkCount, name, campType, imagePath, buttonText;
  final bool isAvailable;
  final Color buttonColor, buttonTextColor;
  const SearchCardData({
    required this.location,
    required this.bookmarkCount,
    required this.name,
    required this.campType,
    required this.imagePath,
    required this.isAvailable,
    required this.buttonText,
    required this.buttonColor,
    required this.buttonTextColor,
  });
}
