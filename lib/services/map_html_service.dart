import '../repositories/camp_map_repository.dart';

class MapHtmlService {
  String buildHtml({
    required double lat,
    required double lng,
    required List<Camp> camps,
    required DateTime date,
  }) {
    final buf = StringBuffer();
    // 현재 위치 마커
    buf.writeln("""
(function(){
  var pos=new kakao.maps.LatLng($lat,$lng);
  new kakao.maps.Marker({position:pos}).setMap(map);
})();
""");
    for (var c in camps) {
      buf.writeln(c.toMarkerJs(date));
    }
    final markers = buf.toString();
    return """
<!DOCTYPE html><html><head><meta charset='utf-8'>
<meta http-equiv='Content-Security-Policy' content='upgrade-insecure-requests'>
<style>html,body,#map{margin:0;padding:0;width:100%;height:100%}</style>
<script>(function(){const o=document.write.bind(document);
document.write=s=>o(s.replace(/http:\\/\\/t1\\.daumcdn\\.net/g,'https://t1.daumcdn.net'));})();</script>
<script src='https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7'></script></head><body>
<div id='map'></div><script>
var map=new kakao.maps.Map(document.getElementById('map'),
  {center:new kakao.maps.LatLng($lat,$lng),level:3});
${buf.toString()}
</script></body></html>
""";
  }
}
