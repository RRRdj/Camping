// tools/export_merged_campgrounds.dart

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../campground_data.dart'; // 실제 위치에 맞춰 조정

/// 공공데이터 서비스키
const _serviceKey =
    'aL18yks/TuI52tnTlLaQJMx9YCVO0R+vqXjDZBmBe3ST78itxBjo6ZKJIvlWWSh2tTqkWFpbpELlGrCuKFlUaw==';

/// 문자열을 소문자화하고, 공백·특수문자를 모두 제거해 매칭 키로 사용합니다.
String _normalizeKey(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), '')           // 공백 제거
    .replaceAll(RegExp(r'[^가-힣a-z0-9]'), ''); // 한글·영숫자 제외 모두 제거

/// GoCamping API에서 아이템을 가져와
/// 정규화 키 → 데이터 맵으로 저장합니다.
Future<Map<String, Map<String, dynamic>>> _loadApiItems() async {
  final uri = Uri.parse('https://apis.data.go.kr/B551011/GoCamping/basedList')
      .replace(queryParameters: {
    'serviceKey': _serviceKey,
    'numOfRows': '5000',
    'pageNo': '1',
    'MobileOS': 'AND',
    'MobileApp': 'camping',
    '_type': 'XML',
  });

  final resp = await http.get(uri);
  if (resp.statusCode != 200) {
    throw Exception('공공데이터 API 오류: \${resp.statusCode}');
  }

  final doc = XmlDocument.parse(utf8.decode(resp.bodyBytes));
  final map = <String, Map<String, dynamic>>{};

  for (var node in doc.findAllElements('item')) {
    final facltNm = node.getElement('facltNm')?.text.trim() ?? '';
    if (facltNm.isEmpty) continue;
    final key = _normalizeKey(facltNm);

    // 추가 필드 (type, location, lineIntro, intro, featureNm)
    final apiType     = node.getElement('facltDivNm')?.text.trim()    ?? '';
    final doNm        = node.getElement('doNm')?.text.trim()         ?? '';
    final sigunguNm   = node.getElement('sigunguNm')?.text.trim()    ?? '';
    final apiLocation = [doNm, sigunguNm].where((e) => e.isNotEmpty).join(' ');
    final lineIntro   = node.getElement('lineIntro')?.text.trim()    ?? '';
    final intro       = node.getElement('intro')?.text.trim()        ?? '';
    final featureNm   = node.getElement('featureNm')?.text.trim()    ?? '';

    map[key] = {
      'contentId'    : node.getElement('contentId')?.text.trim()     ?? '',
      'firstImageUrl': node.getElement('firstImageUrl')?.text.trim() ?? null,
      'amenities'    : (node.getElement('sbrsCl')?.text.trim() ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'inDuty'       : node.getElement('induty')?.text.trim()        ?? '',
      'lctCl'        : node.getElement('lctCl')?.text.trim()         ?? '',
      'addr1'        : node.getElement('addr1')?.text.trim()         ?? '정보없음',
      'tel'          : node.getElement('tel')?.text.trim()           ?? '정보없음',
      'mapX'         : node.getElement('mapX')?.text.trim()          ?? '0',
      'mapY'         : node.getElement('mapY')?.text.trim()          ?? '0',
      'resveUrl'     : node.getElement('resveUrl')?.text.trim()      ?? '정보없음',
      'type'         : apiType,
      'location'     : apiLocation,
      'lineIntro'    : lineIntro,
      'intro'        : intro,
      'featureNm'    : featureNm,
    };
  }

  return map;
}

/// 로컬 campgroundList와 API 데이터를 병합하고,
/// 매칭 실패 키를 stderr에 출력합니다.
Future<List<Map<String, dynamic>>> loadAndMergeData() async {
  final apiMap = await _loadApiItems();
  final merged = <Map<String, dynamic>>[];

  // 디버깅용: 로컬 리스트 vs API 키 차집합 출력
  final campKeys = campgroundList
      .map((c) => _normalizeKey(c['name'] as String))
      .toSet();
  final apiKeys = apiMap.keys.toSet();
  final missing = campKeys.difference(apiKeys);
  if (missing.isNotEmpty) {
    stderr.writeln('⚠️ 다음 캠핑장 키가 API에 없습니다:');
    for (var k in missing) {
      stderr.writeln('  • "\$k"');
    }
  }

  // 실제 병합 로직
  for (var camp in campgroundList) {
    final origName = camp['name'] as String;
    final key      = _normalizeKey(origName);

    if (apiMap.containsKey(key)) {
      merged.add({
        ...camp,
        ...apiMap[key]!,
      });
    } else {
      merged.add({...camp});
    }
  }

  return merged;
}

Future<void> main() async {
  final merged = await loadAndMergeData();

  const outPath = 'lib/tools/json/campground_data.json';
  final file   = File(outPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(merged),
  );

  print('✅ 병합된 캠핑장 데이터 JSON 생성 완료: \$outPath');
}

// 실행 커맨드:
// dart run tools/export_merged_campgrounds.dart
