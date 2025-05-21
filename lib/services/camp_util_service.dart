// services/camp_util_service.dart

import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class CampUtilService {
  /* ── 예약 페이지 URL ── */
  String reservationUrl(String type, String? resveUrl) {
    if (type == '국립') {
      return 'https://reservation.knps.or.kr/reservation/searchSimpleCampReservation.do';
    }
    return resveUrl ?? '';
  }

  /* ── Kakao 지도 HTML (InAppWebView) ── */
  String kakaoMapHtml(double lat, double lng) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
  <style>
    html, body, #map { margin:0; padding:0; width:100%; height:100%; }
  </style>

  <!-- HTTP 타일 URL을 HTTPS 로 치환 -->
  <script>
    (function(){
      const origWrite = document.write.bind(document);
      document.write = s => origWrite(
        s.replace(/http:\\/\\/t1\\.daumcdn\\.net/g,
                  'https://t1.daumcdn.net')
      );
    })();
  </script>

  <!-- 프로토콜을 명시한 HTTPS SDK 로드 -->
  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7"></script>
</head>
<body>
  <div id="map"></div>
  <script>
    // DOM이 준비된 이후 바로 지도 생성
    var map = new kakao.maps.Map(
      document.getElementById('map'),
      { center: new kakao.maps.LatLng($lat, $lng), level: 3 }
    );
    new kakao.maps.Marker({ position: map.getCenter(), map: map });
  </script>
</body>
</html>
''';

  /// DateTime → 'yyyy-MM-dd' 문자열 변환
  String formatDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// 외부 URL을 기본 브라우저(또는 앱)로 엽니다.
  /// 성공적으로 열었으면 true, 아니면 false 리턴.
  Future<bool> openExternalUrl(String url) async {
    if (url.isEmpty) return false;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// 전화번호로 다이얼 시도. 성공하면 true, 아니면 false.
  Future<bool> dial(String phoneNumber) async {
    if (phoneNumber.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }
}
