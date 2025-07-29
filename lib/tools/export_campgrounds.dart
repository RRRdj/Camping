// tools/export_merged_campgrounds.dart

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../campground_data.dart'; // 실제 위치에 맞춰 조정

const _serviceKey = 'aL18yks/TuI52tnTlLaQJMx9YCVO0R+vqXjDZBmBe3ST78itxBjo6ZKJIvlWWSh2tTqkWFpbpELlGrCuKFlUaw==';

/// 공공데이터 API에서 가져온 XML 정보와
/// campground_data.dart 의 static 리스트를 머지합니다.
Future<List<Map<String, dynamic>>> loadAndMergeData() async {
  final url = Uri.parse('https://apis.data.go.kr/B551011/GoCamping/basedList').replace(
    queryParameters: {
      'serviceKey': _serviceKey,
      'numOfRows': '5000',
      'pageNo': '1',
      'MobileOS': 'AND',
      'MobileApp': 'camping',
      '_type': 'XML',
    },
  );
  final resp = await http.get(url);
  if (resp.statusCode != 200) {
    throw Exception('API 호출 실패: ${resp.statusCode}');
  }

  final doc = XmlDocument.parse(utf8.decode(resp.bodyBytes));
  final apiItems = <String, Map<String, dynamic>>{};
  for (var node in doc.findAllElements('item')) {
    final name = node.getElement('facltNm')?.text.trim() ?? '';
    if (name.isEmpty) continue;

    apiItems[name.toLowerCase()] = {
      'contentId'    : node.getElement('contentId')?.text.trim()     ?? '',
      'firstImageUrl': node.getElement('firstImageUrl')?.text.trim() ?? '',
      'amenities'    : (node.getElement('sbrsCl')?.text.trim() ?? '')
          .split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      'inDuty'       : node.getElement('induty')?.text.trim()        ?? '',
      'lctCl'        : node.getElement('lctCl')?.text.trim()         ?? '',
      'addr1'        : node.getElement('addr1')?.text.trim()         ?? '정보없음',
      'tel'          : node.getElement('tel')?.text.trim()           ?? '정보없음',
      'mapX'         : node.getElement('mapX')?.text.trim()          ?? '0',
      'mapY'         : node.getElement('mapY')?.text.trim()          ?? '0',
      'resveUrl'     : node.getElement('resveUrl')?.text.trim()      ?? '정보없음',
    };
  }

  final merged = <Map<String, dynamic>>[];
  for (var camp in campgroundList) {
    final key = (camp['name'] as String).toLowerCase();
    if (!apiItems.containsKey(key)) continue;
    merged.add({
      ...camp,
      ...apiItems[key]!,
    });
  }
  return merged;
}

Future<void> main() async {
  final merged = await loadAndMergeData();

  // 출력 경로
  const outPath = 'lib/tools/json/campground_data.json';
  final file = File(outPath);
  await file.parent.create(recursive: true);

  // pretty-print JSON
  final jsonStr = const JsonEncoder.withIndent('  ').convert(merged);
  await file.writeAsString(jsonStr);

  print('✅ 병합된 캠핑장 데이터 JSON 생성 완료: $outPath');
}

// 터미널에서 dart run lib/tools/export_campgrounds.dart