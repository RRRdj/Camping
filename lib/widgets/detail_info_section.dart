// lib/widgets/detail_info_section.dart
import 'package:flutter/material.dart';
import 'expandable_text.dart';

class DetailInfoSection extends StatelessWidget {
  final String? lineIntro;
  final String? intro;
  final String? featureNm;

  const DetailInfoSection({
    super.key,
    this.lineIntro,
    this.intro,
    this.featureNm,
  });

  @override
  Widget build(BuildContext context) {
    final hasLineIntro = (lineIntro ?? '').isNotEmpty;
    final hasIntro = (intro ?? '').isNotEmpty;
    final hasFeature = (featureNm ?? '').isNotEmpty;

    if (!hasLineIntro && !hasIntro && !hasFeature) {
      return const Text(
        '자세한 정보를 찾으시려면 예약현황이나 사이트를 통해서 확인하세요.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasLineIntro) ExpandableText(lineIntro!, trimLines: 3),
        if (hasIntro || hasFeature) const SizedBox(height: 4),
        ExpandableText(hasIntro ? intro! : (featureNm ?? ''), trimLines: 5),
      ],
    );
  }
}
