/// lib/services/go_camping_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// 서비스 전용: 공공 Go-Camping 이미지 API 래퍼
class GoCampingService {
  static const _serviceKey =
      'aL18yks/TuI52tnTlLaQJMx9YCVO0R+vqXjDZBmBe3ST78itxBjo6ZKJIvlWWSh2tTqkWFpbpELlGrCuKFlUaw==';

  Future<List<String>> fetchImages(String contentId, String? firstUrl) async {
    if (contentId.isEmpty) return [];

    final uri = Uri.parse(
      'https://apis.data.go.kr/B551011/GoCamping/imageList',
    ).replace(
      queryParameters: {
        'serviceKey': _serviceKey,
        'contentId': contentId,
        'MobileOS': 'AND',
        'MobileApp': 'camping',
        'numOfRows': '20',
        'pageNo': '1',
        '_type': 'XML',
      },
    );

    final resp = await http.get(uri);
    if (resp.statusCode != 200) return [];

    final doc = XmlDocument.parse(utf8.decode(resp.bodyBytes));
    final urls =
        doc
            .findAllElements('imageUrl')
            .map((e) => e.text.trim())
            .where((u) => u.isNotEmpty)
            .toList();

    if (firstUrl != null && firstUrl.isNotEmpty && !urls.contains(firstUrl)) {
      urls.insert(0, firstUrl);
    }
    return urls;
  }
}
