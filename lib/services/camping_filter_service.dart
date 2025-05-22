import 'package:intl/intl.dart';

/// 검색·필터·정렬 전담 Service
class CampingFilterService {
  /* ── 선택지 생성 ── */
  List<String> regions(List<Map<String, dynamic>> camps) => _distinctSorted(
    camps.map((c) => (c['location'] as String).split(' ').first),
  );

  List<String> types(List<Map<String, dynamic>> camps) =>
      _distinctSorted(camps.map((c) => c['type'] as String));

  List<String> duties(List<Map<String, dynamic>> camps) => _distinctSorted(
    camps.expand(
      (c) =>
          (c['inDuty'] as String? ?? '').split(',').where((s) => s.isNotEmpty),
    ),
  );

  List<String> envs(List<Map<String, dynamic>> camps) => _distinctSorted(
    camps.map((c) => c['lctCl'] as String? ?? '').where((e) => e.isNotEmpty),
  );

  List<String> amenities(List<Map<String, dynamic>> camps) => _distinctSorted(
    camps
        .expand((c) => (c['amenities'] as List<dynamic>? ?? []))
        .cast<String>(),
  );

  /* ── 필터 & 정렬 ── */
  List<Map<String, dynamic>> apply({
    required List<Map<String, dynamic>> camps,
    required Map<String, Map<String, dynamic>> availability,
    required DateTime date,
    String? keyword,
    String? region,
    String? type,
    String? duty,
    String? env,
    String? amenity,
  }) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);

    final filtered =
        camps.where((c) {
          final name = (c['name'] as String).toLowerCase();
          if (keyword != null &&
              keyword.isNotEmpty &&
              !name.contains(keyword.toLowerCase())) {
            return false;
          }
          if (region != null &&
              (c['location'] as String).split(' ').first != region) {
            return false;
          }
          if (type != null && c['type'] != type) {
            return false;
          }
          if (duty != null) {
            final duties = (c['inDuty'] as String? ?? '')
                .split(',')
                .where((s) => s.isNotEmpty);
            if (!duties.contains(duty)) return false;
          }
          if (env != null && (c['lctCl'] as String? ?? '') != env) {
            return false;
          }
          if (amenity != null &&
              !((c['amenities'] as List<dynamic>? ?? []).contains(amenity))) {
            return false;
          }
          return true;
        }).toList();

    /* 가용 수량 기준 내림차순 정렬 */
    filtered.sort((a, b) {
      final aAv = _available(
        a['name'],
        availability,
        dateKey,
        fallback: a['available'],
      );
      final bAv = _available(
        b['name'],
        availability,
        dateKey,
        fallback: b['available'],
      );
      return bAv.compareTo(aAv);
    });

    return filtered;
  }

  /* ── 내부 유틸 ── */
  List<String> _distinctSorted(Iterable<String> it) {
    final list = it.toSet().toList()..sort();
    return list;
  }

  int _available(
    String campName,
    Map<String, Map<String, dynamic>> avail,
    String dateKey, {
    int? fallback,
  }) {
    return avail[campName]?[dateKey]?['available'] as int? ?? (fallback ?? 0);
  }
}
