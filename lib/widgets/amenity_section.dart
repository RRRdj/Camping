/// lib/widgets/amenity_section.dart
import 'package:flutter/material.dart';

/// 캠핑장 편의시설 칩 리스트 표시
class AmenitySection extends StatelessWidget {
  final List<String> amenities;
  const AmenitySection({Key? key, required this.amenities}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (amenities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '편의시설 정보가 없습니다.\n전화로 문의하세요',
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '편의시설',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: amenities.map((e) => Chip(label: Text(e))).toList(),
        ),
      ],
    );
  }
}
