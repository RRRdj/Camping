import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class CampingSitesPage extends StatefulWidget {
  const CampingSitesPage({Key? key}) : super(key: key);

  @override
  _CampingSitesPageState createState() => _CampingSitesPageState();
}

class _CampingSitesPageState extends State<CampingSitesPage> {
  // contentId별 이미지 URL을 저장할 맵
  final Map<String, String> imageUrls = {};
  bool isLoadingImages = true;

  @override
  void initState() {
    super.initState();
    fetchImages();
  }

  /// contentId 362, 363, 364에 대해 API 호출하여 이미지 URL을 가져오는 함수
  Future<void> fetchImages() async {
    const List<String> contentIds = ['362', '363', '364'];
    // 이미지 API에 사용할 URL 인코딩된 서비스키
    const String serviceKey =
        '0wd8kVe4L75w5XaOYAd9iM0nbI9lgSRJLIDVsN78hfbIauGBbgdIqrwWDC%2B%2F10qT4MMw6KSWAAlB6dXNuGEpLQ%3D%3D';

    for (String id in contentIds) {
      final url = Uri.parse(
        'https://apis.data.go.kr/B551011/GoCamping/imageList'
        '?numOfRows=1'
        '&pageNo=1'
        '&MobileOS=AND'
        '&MobileApp=camping'
        '&serviceKey=$serviceKey'
        '&_type=XML'
        '&contentId=$id',
      );

      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final decodedBody = utf8.decode(response.bodyBytes);
          final parsedXml = xml.XmlDocument.parse(decodedBody);
          final imageElements = parsedXml.findAllElements('imageUrl');
          if (imageElements.isNotEmpty) {
            final imageUrl = imageElements.first.text;
            setState(() {
              imageUrls[id] = imageUrl;
            });
          } else {
            setState(() {
              imageUrls[id] = ''; // 이미지 URL이 없는 경우 빈 문자열 처리
            });
          }
        } else {
          setState(() {
            imageUrls[id] = '';
          });
        }
      } catch (e) {
        setState(() {
          imageUrls[id] = '';
        });
      }
    }
    setState(() {
      isLoadingImages = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 각 카드에 contentId 362, 363, 364에 해당하는 이미지를 사용
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '경북 야영장',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.black),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5EFF7),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 16.0),
                      child: Text(
                        '구미',
                        style: TextStyle(color: Colors.black54, fontSize: 15),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      icon: const Icon(Icons.search, color: Colors.black54),
                      onPressed: () {
                        Navigator.pushNamed(context, '/search_result');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter Tags
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 10.0,
              ),
              child: Row(
                children: [
                  _buildFilterTag('지자체'),
                  const SizedBox(width: 10),
                  _buildFilterTag('국립공원'),
                ],
              ),
            ),
          ),

          // Camping Sites List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ListView(
                children: [
                  // 1) 구미 캠핑장 (contentId: '362')
                  InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/camping_info');
                    },
                    child: _buildCampSiteCard(
                      image:

                          isLoadingImages
                              ? 'https://via.placeholder.com/75x56?text=Loading'
                              : (imageUrls['362']?.isNotEmpty == true
                                  ? imageUrls['362']!
                                  : 'https://via.placeholder.com/75x56?text=No+Image'),
                      location: '경북 구미시',
                      stars: 180,
                      name: '구미 캠핑장',
                      type: '지자체야영장',
                      isAvailable: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 2) 소백산삼가야영장 (contentId: '363')
                  _buildCampSiteCard(
                    image:
                        isLoadingImages
                            ? 'https://via.placeholder.com/75x56?text=Loading'
                            : (imageUrls['1718']?.isNotEmpty == true
                                ? imageUrls['1718']!
                                : 'https://via.placeholder.com/75x56?text=No+Image'),
                    location: '경북 영주시',
                    stars: 10,
                    name: '소백산삼가야영장',
                    type: '국립공원 야영장',
                    isAvailable: false,
                  ),
                  const SizedBox(height: 10),
                  // 3) 구미 금오산야영장 (contentId: '364')
                  _buildCampSiteCard(
                    image:
                        isLoadingImages
                            ? 'https://via.placeholder.com/75x56?text=Loading'
                            : (imageUrls['480']?.isNotEmpty == true
                                ? imageUrls['480']!
                                : 'https://via.placeholder.com/75x56?text=No+Image'),
                    location: '경북 구미시',
                    stars: 60,
                    name: '구미 금오산야영장',
                    type: '지자체야영장',
                    isAvailable: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '#$text',
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }

  Widget _buildCampSiteCard({
    required String image,
    required String location,
    required int stars,
    required String name,
    required String type,
    bool isAvailable = true,
    bool hasAvailabilityTag = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // 캠핑장 이미지를 네트워크 URL로 로딩 (API 결과 사용)
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                image,
                width: 75,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 75,
                    height: 56,
                    color: Colors.grey,
                    child: const Icon(Icons.error, color: Colors.red),
                  );
                },
              ),
            ),
          ),

          // 캠핑장 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, color: Colors.amber, size: 12),
                    Text(
                      ' $stars',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          // 예약 상태 태그
          if (hasAvailabilityTag)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  isAvailable ? '예약 가능' : '예약 마감',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
