import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// DB 및 외부 API 통신 전담 레포지토리
class CampRepository {
  static const _serviceKey =
      'aL18yks/TuI52tnTlLaQJMx9YCVO0R+vqXjDZBmBe3ST78itxBjo6ZKJIvlWWSh2tTqkWFpbpELlGrCuKFlUaw==';

  /// 캠핑장 기본 정보 가져오기 (Firestore)
  Future<DocumentSnapshot<Map<String, dynamic>>> fetchCamp(String campName) {
    return FirebaseFirestore.instance
        .collection('campgrounds')
        .doc(campName)
        .get();
  }

  /// 공공데이터 포털 이미지 목록 가져오기
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
