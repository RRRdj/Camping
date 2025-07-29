import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class CampImageRepository {
  CampImageRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static const _serviceKey =
      '0wd8kVe4L75w5XaOYAd9iM0nbI9lgSRJLIDVsN78hfbIauGBbgdIqrwWDC%2B%2F10qT4MMw6KSWAAlB6dXNuGEpLQ%3D%3D';

  /// contentId 리스트를 받아 <contentId, imageUrl> 맵을 반환
  Future<Map<String, String>> fetchImageUrls(List<String> ids) async {
    final Map<String, String> result = {};
    for (final id in ids) {
      result[id] = await _fetchSingle(id);
    }
    return result;
  }

  Future<String> _fetchSingle(String id) async {
    final uri = Uri.parse(
      'https://apis.data.go.kr/B551011/GoCamping/imageList'
      '?numOfRows=1&pageNo=1&MobileOS=AND&MobileApp=camping'
      '&serviceKey=$_serviceKey&_type=XML&contentId=$id',
    );
    try {
      final resp = await _client.get(uri);
      if (resp.statusCode != 200) return '';
      final doc = xml.XmlDocument.parse(utf8.decode(resp.bodyBytes));
      final elm = doc.findAllElements('imageUrl').firstOrNull;
      return elm?.text ?? '';
    } catch (_) {
      return '';
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
