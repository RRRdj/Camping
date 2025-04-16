import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'camping_reservation_screen.dart';
// 만약 CampingReservationScreen이 다른 파일에 있다면 import 해주세요.
// import 'camping_reservation_screen.dart';

/// 캠핑장 정보를 담을 모델 클래스
class CampingItem {
  final String contentId;
  final String facltNm;
  final String addr1;
  final String lineIntro;
  final String sbrsEtc; // 부가시설 정보
  final String facltDivNm; // 캠핑장 구분
  final String homepage; // 홈페이지 주소
  final String tel; // 전화번호

  CampingItem({
    required this.contentId,
    required this.facltNm,
    required this.addr1,
    required this.lineIntro,
    required this.sbrsEtc,
    required this.facltDivNm,
    required this.homepage,
    required this.tel,
  });
}

class CampingInfoScreen extends StatefulWidget {
  const CampingInfoScreen({Key? key}) : super(key: key);

  @override
  State<CampingInfoScreen> createState() => _CampingInfoScreenState();
}

class _CampingInfoScreenState extends State<CampingInfoScreen> {
  /// 단일 캠핑장 정보를 담을 변수
  CampingItem? campingItem;

  bool isLoading = false;
  String? errorMessage;

  String? extraImageUrl;
  bool isImageLoading = false;
  String? imageErrorMessage;

  @override
  void initState() {
    super.initState();
    // contentId=362번 데이터를 가져옴
    fetchSingleCampingData();
    // 이미지 URL도 가져옴
    fetchExtraImage();
  }

  /// contentId가 362번인 캠핑장 정보를 하나만 가져오는 함수
  Future<void> fetchSingleCampingData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final serviceKey =
        '0wd8kVe4L75w5XaOYAd9iM0nbI9lgSRJLIDVsN78hfbIauGBbgdIqrwWDC+/10qT4MMw6KSWAAlB6dXNuGEpLQ==';

    final url = Uri.parse(
      'https://apis.data.go.kr/B551011/GoCamping/basedList',
    ).replace(
      queryParameters: {
        'serviceKey': serviceKey,
        'numOfRows': '3000',
        'pageNo': '1',
        'MobileOS': 'AND',
        'MobileApp': 'camping',
        '_type': 'XML',
      },
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // 한글 깨짐 문제 해결을 위해 UTF-8 디코딩
        final decodedBody = utf8.decode(response.bodyBytes);
        final document = xml.XmlDocument.parse(decodedBody);

        // 모든 <item> 노드 중 contentId가 "362"인 항목만 필터링
        final items =
            document.findAllElements('item').where((node) {
              final contentIdElement = node.getElement('contentId');
              return contentIdElement != null &&
                  contentIdElement.text.trim() == '362';
            }).toList();

        if (items.isNotEmpty) {
          // 첫 번째 아이템만 사용
          final node = items.first;
          final contentId = node.getElement('contentId')?.text.trim() ?? '';
          final facltNm = node.getElement('facltNm')?.text.trim() ?? '';
          final addr1 = node.getElement('addr1')?.text.trim() ?? '';
          final lineIntro = node.getElement('lineIntro')?.text.trim() ?? '';
          final sbrsEtc = node.getElement('sbrsEtc')?.text.trim() ?? '';
          final facltDivNm = node.getElement('facltDivNm')?.text.trim() ?? '';
          final homepage = node.getElement('homepage')?.text.trim() ?? '';
          final tel = node.getElement('tel')?.text.trim() ?? '';

          setState(() {
            campingItem = CampingItem(
              contentId: contentId,
              facltNm: facltNm,
              addr1: addr1,
              lineIntro: lineIntro,
              sbrsEtc: sbrsEtc,
              facltDivNm: facltDivNm,
              homepage: homepage,
              tel: tel,
            );
          });
        } else {
          setState(() {
            errorMessage = '해당 contentId=362 데이터가 없습니다.';
          });
        }
      } else {
        setState(() {
          errorMessage = '오류 발생: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = '예외 발생: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// 특정 이미지 URL을 가져오는 함수
  Future<void> fetchExtraImage() async {
    setState(() {
      isImageLoading = true;
      imageErrorMessage = null;
    });

    final url = Uri.parse(
      'https://apis.data.go.kr/B551011/GoCamping/imageList'
      '?numOfRows=1'
      '&pageNo=1'
      '&MobileOS=AND'
      '&MobileApp=camping'
      '&serviceKey=0wd8kVe4L75w5XaOYAd9iM0nbI9lgSRJLIDVsN78hfbIauGBbgdIqrwWDC%2B%2F10qT4MMw6KSWAAlB6dXNuGEpLQ%3D%3D'
      '&_type=XML'
      '&contentId=362',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final document = xml.XmlDocument.parse(decodedBody);
        final imageElements = document.findAllElements('imageUrl');
        if (imageElements.isNotEmpty) {
          setState(() {
            extraImageUrl = imageElements.first.text.trim();
          });
        } else {
          setState(() {
            imageErrorMessage = "이미지 URL을 찾을 수 없습니다.";
          });
        }
      } else {
        setState(() {
          imageErrorMessage = '이미지 API 오류: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        imageErrorMessage = '이미지 API 예외 발생: $e';
      });
    } finally {
      setState(() {
        isImageLoading = false;
      });
    }
  }

  /// 개별 리뷰를 표시하는 위젯
  Widget _buildReview({
    required String name,
    required String date,
    required int rating,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(date, style: const TextStyle(color: Colors.black)),
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: Colors.green,
              size: 20,
            );
          }),
        ),
        Text(content),
        const SizedBox(height: 16),
      ],
    );
  }

  /// API를 통해 받아온 단일 캠핑장 텍스트 정보를 표시하는 위젯
  Widget _buildCampingInfoText() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(child: Text(errorMessage!));
    }
    if (campingItem == null) {
      return const SizedBox.shrink();
    }

    return Text(
      '정보 \n\n'
      '캠핑장 이름: ${campingItem!.facltNm}\n'
      '주소: ${campingItem!.addr1}\n'
      '한줄소개: ${campingItem!.lineIntro}\n'
      '부가시설: ${campingItem!.sbrsEtc}\n'
      '캠핑장 구분: ${campingItem!.facltDivNm}\n'
      '홈페이지: ${campingItem!.homepage}\n'
      '전화번호: ${campingItem!.tel}\n',
      style: const TextStyle(fontSize: 16),
    );
  }

  /// API로 받아온 이미지를 표시하는 위젯
  Widget _buildExtraImageSection() {
    if (isImageLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (imageErrorMessage != null) {
      return Center(child: Text(imageErrorMessage!));
    }
    if (extraImageUrl != null && extraImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(extraImageUrl!, height: 200, fit: BoxFit.cover),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('구미 캠핑장'), leading: const BackButton()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 예약 현황 버튼 (onPressed 수정)
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CampingReservationScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
              ),
              child: const Text('예약 현황'),
            ),
            const SizedBox(height: 24),
            _buildCampingInfoText(),
            // 사진 영역 (API로 받아온 이미지 표시)
            const Text(
              '사진',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildExtraImageSection(),
            const SizedBox(height: 20),
            // 후기 작성 버튼
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/review');
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 40),
              ),
              child: const Text('후기 작성'),
            ),
            const SizedBox(height: 24),
            // 후기 리스트 영역
            const Text(
              '후기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildReview(
              name: '익명',
              date: '2025-03-24',
              rating: 5,
              content: '캠핑장이 정말 깨끗하고 시설이 좋아요.',
            ),
            _buildReview(
              name: '김철수',
              date: '2025-03-26',
              rating: 4,
              content: '주차 공간이 넓고 편리했어요.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
