// lib/widgets/kakao_map_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class KakaoMapView extends StatelessWidget {
  final double lat;
  final double lng;

  const KakaoMapView({super.key, required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    final html = '''
<!DOCTYPE html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="upgrade-insecure-requests">
<style>html,body,#map{margin:0;padding:0;width:100%;height:100%;}</style>
<script>(function(){const _old=document.write.bind(document);
document.write=function(s){_old(s.replace(/http:\\/\\/t1\\.daumcdn\\.net/g,
'https://t1.daumcdn.net'));};})();</script>
<script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=4807f3322c219648ee8e346b3bfea1d7"></script></head><body>
<div id="map"></div><script>
const coord=new kakao.maps.LatLng($lat,$lng);
const map=new kakao.maps.Map(document.getElementById('map'),
{center:coord,level:3});
const marker=new kakao.maps.Marker({position:coord});marker.setMap(map);
kakao.maps.event.addListener(map,'idle',()=>map.setCenter(coord));
</script></body></html>''';

    return SizedBox(
      height: 200,
      child: InAppWebView(
        initialData: InAppWebViewInitialData(data: html),
        initialOptions: InAppWebViewGroupOptions(
          android: AndroidInAppWebViewOptions(
            mixedContentMode:
                AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          ),
          ios: IOSInAppWebViewOptions(allowsInlineMediaPlayback: true),
        ),
      ),
    );
  }
}
