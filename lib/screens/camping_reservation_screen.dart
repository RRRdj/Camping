import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  // 플랫폼 초기화를 보장합니다.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camping Reservation',
      home: CampingReservationScreen(),
    );
  }
}

class CampingReservationScreen extends StatefulWidget {
  @override
  _ReservationWebViewScreenState createState() =>
      _ReservationWebViewScreenState();
}

class _ReservationWebViewScreenState extends State<CampingReservationScreen> {
  InAppWebViewController? _webViewController;

  @override
  Widget build(BuildContext context) {
    // InAppWebView 플랫폼 구현체가 없으면 안내 메시지를 표시합니다.
    if (InAppWebViewPlatform.instance == null) {
      return Scaffold(
        appBar: AppBar(title: Text("예약 현황 (WebView)")),
        body: Center(
          child: Text(
            "InAppWebView 플랫폼 구현체가 설정되지 않았습니다.\n지원되는 플랫폼(Android/iOS)에서 실행해주세요.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text("예약 현황")),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(
            'https://reservation.knps.or.kr/reservation/searchSimpleCampReservation.do',
          ),
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
        },
      ),
    );
  }
}
