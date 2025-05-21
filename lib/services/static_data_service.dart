// lib/services/static_data_service.dart

/// 앱 전역에서 쓰는 고정 태그 목록, placeholder URL, contentId 리스트 등을 모았습니다.
class StaticDataService {
  /// 검색 화면 & 캠핑장 타입 필터
  static const List<String> regions = [
    '서울',
    '경기',
    '강원',
    '충남/대전',
    '경북',
    '경남',
    '전북/전남',
    '제주',
  ];
  static const List<String> facilities = [
    '전기',
    '무선인터넷',
    '장작판매',
    '온수',
    '운동시설',
    '샤워실',
    '매점',
  ];
  static const List<String> campTypes = ['국립캠핑장', '지자체캠핑장'];

  /// NearbyMapPage 샘플용 contentId
  static const List<String> contentIds = ['362', '363', '364'];

  /// 캠핑장 썸네일 없을 때
  static String placeholder([String text = 'No+Image']) =>
      'https://via.placeholder.com/75x56?text=$text';

  /// CampUtilService 기본 아바타 URL 생성
  static String avatarSeed(String uid) =>
      'https://api.dicebear.com/6.x/adventurer/png?seed=$uid&size=150';
}
