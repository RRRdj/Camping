// lib/widgets/site_button.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SiteButton extends StatelessWidget {
  final String? siteUrl;
  const SiteButton({super.key, required this.siteUrl});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
      onPressed: () async {
        if (siteUrl == null || siteUrl!.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('사이트 정보가 없습니다.')));
          return;
        }
        final uri = Uri.parse(siteUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('사이트를 열 수 없습니다.')));
        }
      },
      child: const Text('홈페이지 이동', style: TextStyle(color: Colors.white)),
    );
  }
}
