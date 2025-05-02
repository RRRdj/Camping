import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:url_launcher/url_launcher.dart';

/// 리뷰 데이터 모델
class Review {
  final String name;
  final int rating;
  final String content;
  final String date;

  Review({
    required this.name,
    required this.rating,
    required this.content,
    required this.date,
  });
}

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
  CampingItem? campingItem;
  bool isLoading = false;
  String? errorMessage;

  String? extraImageUrl;
  bool isImageLoading = false;
  String? imageErrorMessage;

  // 리뷰 관련 컨트롤러 및 데이터
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();
  int _selectedRating = 5;
  final List<Review> _reviews = [
    Review(
      name: '익명',
      rating: 5,
      content: '캠핑장이 정말 깨끗하고 시설이 좋아요.',
      date: '2025-03-24',
    ),
    Review(
      name: '김철수',
      rating: 4,
      content: '주차 공간이 넓고 편리했어요.',
      date: '2025-03-26',
    ),
  ];

  @override
  void initState() {
    super.initState();
    fetchSingleCampingData();
    fetchExtraImage();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> fetchSingleCampingData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    const serviceKey =
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
        final decodedBody = utf8.decode(response.bodyBytes);
        final document = xml.XmlDocument.parse(decodedBody);

        final items =
            document.findAllElements('item').where((node) {
              final id = node.getElement('contentId')?.text.trim();
              return id == '362';
            }).toList();

        if (items.isNotEmpty) {
          final node = items.first;
          final item = CampingItem(
            contentId: node.getElement('contentId')?.text.trim() ?? '',
            facltNm: node.getElement('facltNm')?.text.trim() ?? '',
            addr1: node.getElement('addr1')?.text.trim() ?? '',
            lineIntro: node.getElement('lineIntro')?.text.trim() ?? '',
            sbrsEtc: node.getElement('sbrsEtc')?.text.trim() ?? '',
            facltDivNm: node.getElement('facltDivNm')?.text.trim() ?? '',
            homepage: node.getElement('homepage')?.text.trim() ?? '',
            tel: node.getElement('tel')?.text.trim() ?? '',
          );
          if (!mounted) return;
          setState(() => campingItem = item);
        } else {
          if (!mounted) return;
          setState(() => errorMessage = '해당 contentId=362 데이터가 없습니다.');
        }
      } else {
        if (!mounted) return;
        setState(() => errorMessage = '오류 발생: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = '예외 발생: $e');
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchExtraImage() async {
    setState(() {
      isImageLoading = true;
      imageErrorMessage = null;
    });

    const imageUrl =
        'https://apis.data.go.kr/B551011/GoCamping/imageList?numOfRows=1&pageNo=1&MobileOS=AND&MobileApp=camping&serviceKey=0wd8kVe4L75w5XaOYAd9iM0nbI9lgSRJLIDVsN78hfbIauGBbgdIqrwWDC%2B%2F10qT4MMw6KSWAAlB6dXNuGEpLQ%3D%3D&_type=XML&contentId=362';

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final document = xml.XmlDocument.parse(decodedBody);
        final images = document.findAllElements('imageUrl').toList();
        if (images.isNotEmpty) {
          if (!mounted) return;
          setState(() => extraImageUrl = images.first.text.trim());
        } else {
          if (!mounted) return;
          setState(() => imageErrorMessage = '이미지 URL을 찾을 수 없습니다.');
        }
      } else {
        if (!mounted) return;
        setState(
          () => imageErrorMessage = '이미지 API 오류: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => imageErrorMessage = '이미지 API 예외 발생: $e');
    } finally {
      if (!mounted) return;
      setState(() => isImageLoading = false);
    }
  }

  void _addReview() {
    if (_nameController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty)
      return;

    setState(() {
      _reviews.insert(
        0,
        Review(
          name: _nameController.text.trim(),
          rating: _selectedRating,
          content: _contentController.text.trim(),
          date: DateTime.now().toString().split(' ').first,
        ),
      );
      _nameController.clear();
      _contentController.clear();
      _selectedRating = 5;
    });
  }

  Widget _buildReview(Review review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(review.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(review.date),
        Row(
          children: List.generate(5, (i) {
            return Icon(
              i < review.rating ? Icons.star : Icons.star_border,
              color: Colors.green,
              size: 20,
            );
          }),
        ),
        Text(review.content),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCampingInfoText() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (errorMessage != null) return Center(child: Text(errorMessage!));
    if (campingItem == null) return const SizedBox.shrink();

    return Text(
      '주소: ${campingItem!.addr1}\n'
      '한줄소개: ${campingItem!.lineIntro}\n'
      '부가시설: ${campingItem!.sbrsEtc}\n'
      '캠핑장 구분: ${campingItem!.facltDivNm}\n',
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildExtraImageSection() {
    if (isImageLoading) return const Center(child: CircularProgressIndicator());
    if (imageErrorMessage != null)
      return Center(child: Text(imageErrorMessage!));
    if (extraImageUrl?.isNotEmpty ?? false) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(extraImageUrl!, height: 200, fit: BoxFit.cover),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL을 열 수 없습니다.')));
    }
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
            // 홈페이지 & 전화번호 버튼 행
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        () => _launchUrl('tel:${campingItem?.tel ?? ''}'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('전화'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _launchUrl(campingItem?.homepage ?? ''),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('홈페이지'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildCampingInfoText(),
            const SizedBox(height: 24),
            const Text(
              '사진',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildExtraImageSection(),
            const SizedBox(height: 24),
            // 리뷰 입력 섹션
            const Text(
              '리뷰 작성',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '닉네임',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('평점: '),
                DropdownButton<int>(
                  value: _selectedRating,
                  items: List.generate(5, (i) {
                    final rating = i + 1;
                    return DropdownMenuItem(
                      value: rating,
                      child: Text('$rating'),
                    );
                  }),
                  onChanged:
                      (value) => setState(
                        () => _selectedRating = value ?? _selectedRating,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '내용',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _addReview,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green,
                ),
                child: const Text('등록'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '후기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._reviews.map(_buildReview),
          ],
        ),
      ),
    );
  }
}
