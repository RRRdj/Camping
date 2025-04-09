import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 간단한 앱 예시
/// main() -> MyApp -> DetailScreen 으로 이동
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 라우팅 설정
      routes: {
        '/': (context) => const HomeScreen(),
        '/detail': (context) => const DetailScreen(),
      },
      initialRoute: '/',
    );
  }
}

/// 홈 스크린에서 상세 스크린으로 이동하는 버튼을 가진 예시
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홈 화면')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // 예시로 "0410" 지역(혹은 ID)을 넘긴다고 가정
            Navigator.pushNamed(context, '/detail', arguments: '0411');
          },
          child: const Text('상세 화면으로 이동'),
        ),
      ),
    );
  }
}

/// 실제로 "RCCnt0410" 데이터를 가져와서
/// 0이면 "아니오", 0이 아니면 "예"를 표시하는 예시 코드
class DetailScreen extends StatelessWidget {
  const DetailScreen({Key? key}) : super(key: key);

  /// 실제 동적 로딩용 API를 찾아서 여기에 요청
  /// 아래는 가상의 예시 URL(getCampCalendarAjax.do)과 파라미터를 넣은 코드
  Future<String> _fetchRCCntValue(String regionCode) async {
    try {
      // 1) Network 탭에서 확인한 동적 로딩용 API를 사용
      //    예: getCampCalendarAjax.do (실제 이름, URL, 파라미터는 다를 수 있음)
      final response = await http.post(
        Uri.parse('https://res.knps.or.kr/reservation/getCampCalendarAjax.do'),
        headers: {
          // 필요하다면 쿠키, X-Requested-With 등도 넣어야 할 수 있음
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: {
          // regionCode(예: "0410")를 전달한다고 가정
          // month, 다른 파라미터 등도 필요하다면 추가
          'areaCode': regionCode,
          'month': '202304', // 예시: 2023년 4월
        },
      );

      if (response.statusCode == 200) {
        // 2) 응답이 JSON 형태라고 가정하고 디코딩
        //    (실제로 JSON인지, HTML 조각인지, XML인지 확인 필요)
        final jsonBody = jsonDecode(response.body);

        // 3) 여기서 "RCCnt0410"과 같은 key를 찾아서 값을 가져옴
        //    만약 key가 "RCCnt${regionCode}" 형태라면:
        final keyName = 'RCCnt$regionCode'; // 예: regionCode = 0410 -> RCCnt0410
        final value = jsonBody[keyName] ?? '0';

        return value.toString().trim();
      } else {
        // 상태 코드가 200이 아닐 경우
        return '0';
      }
    } catch (e) {
      // 요청 또는 파싱 중 에러가 발생하면 기본값 '0'을 반환
      return '0';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 다른 화면에서 넘어온 regionCode (예: "0410")
    final regionCode = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(title: Text('$regionCode 캠핑장')),
      body: Center(
        child: FutureBuilder<String>(
          future: _fetchRCCntValue(regionCode),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // 비동기 요청 중이면 로딩 인디케이터 표시
              return const CircularProgressIndicator();
            } else if (snapshot.hasError) {
              // 에러가 있다면 표시
              return Text('에러 발생: ${snapshot.error}');
            } else {
              // 데이터 수신 완료
              final value = snapshot.data ?? '0';
              final isZero = (int.tryParse(value) ?? 0) == 0;

              // 문자열 '0'이면 "아니오", 아니면 "예"
              return Text(
                '${isZero ? '아니오' : '예'} - 전달받은 값: $value',
                style: const TextStyle(fontSize: 18),
              );
            }
          },
        ),
      ),
    );
  }
}
