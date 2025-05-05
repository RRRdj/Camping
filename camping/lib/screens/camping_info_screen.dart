// lib/screens/camping_info_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'camping_reservation_screen.dart';

class CampingInfoScreen extends StatefulWidget {
  final Map<String, dynamic> camp;

  const CampingInfoScreen({
    Key? key,
    required this.camp,
  }) : super(key: key);

  @override
  State<CampingInfoScreen> createState() => _CampingInfoScreenState();
}

class _CampingInfoScreenState extends State<CampingInfoScreen> {
  static const _serviceKey = 'aL18yks/TuI52tnTlLaQJMx9YCVO0R+vqXjDZBmBe3ST78itxBjo6ZKJIvlWWSh2tTqkWFpbpELlGrCuKFlUaw==';

  late Future<List<String>> _imagesFuture;
  bool _showAllAmenities = false;
  bool _bookmarked = false;

  final _nicknameController = TextEditingController();
  final _contentController  = TextEditingController();
  int _rating = 5;

  static const Map<String, IconData> _amenityIcons = {
    '전기':         Icons.flash_on,
    '무선인터넷':   Icons.wifi,
    '장작판매':     Icons.local_fire_department,
    '온수':         Icons.hot_tub,
    '트램플린':     Icons.sports,
    '물놀이장':     Icons.pool,
    '놀이터':       Icons.child_friendly,
    '산책로':       Icons.directions_walk,
    '운동시설':     Icons.fitness_center,
    '마트.편의점':  Icons.store,
  };

  @override
  void initState() {
    super.initState();
    _imagesFuture = _fetchImages();
  }

  Future<List<String>> _fetchImages() async {
    final contentId = widget.camp['contentId'] as String;
    final uri = Uri.parse('https://apis.data.go.kr/B551011/GoCamping/imageList').replace(
      queryParameters: {
        'serviceKey': _serviceKey,
        'contentId': contentId,
        'MobileOS': 'AND',
        'MobileApp': 'camping',
        'numOfRows': '20',
        'pageNo': '1',
        '_type': 'XML',
      },
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return [];
    final doc = XmlDocument.parse(utf8.decode(resp.bodyBytes));
    final urls = doc
        .findAllElements('imageUrl')
        .map((e) => e.text.trim())
        .where((u) => u.isNotEmpty)
        .toList();

    final first = widget.camp['firstImageUrl'] as String? ?? '';
    if (first.isNotEmpty && !urls.contains(first)) {
      urls.insert(0, first);
    }
    return urls;
  }

  Future<void> _launchDialer(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('전화 앱을 열 수 없습니다.')));
    }
  }

  void _submitReview() {
    final nick = _nicknameController.text.trim();
    final content = _contentController.text.trim();
    if (nick.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임과 내용을 모두 입력해주세요.')),
      );
      return;
    }
    setState(() {
      _nicknameController.clear();
      _contentController.clear();
      _rating = 5;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('리뷰가 등록되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camp = widget.camp;
    final dateLabel = DateFormat('MM월 dd일').format(DateTime.now().add(const Duration(days: 1)));
    final name      = camp['name']      as String;
    final location  = camp['location']  as String?  ?? '정보없음';
    final type      = camp['type']      as String?  ?? '정보없음';
    final inDuty    = camp['inDuty']    as String?  ?? '정보없음';
    final lctCl     = camp['lctCl']     as String?  ?? '';
    final addr      = camp['addr1']     as String?  ?? '정보없음';
    final tel       = camp['tel']       as String?  ?? '정보없음';
    final available = camp['available'] as int?     ?? 0;
    final total     = camp['total']     as int?     ?? 0;
    final isAvail   = available > 0;
    final amenities = (camp['amenities'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final displayedAmenities = !_showAllAmenities && amenities.length > 4
        ? amenities.take(4).toList() : amenities;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            backgroundColor: Colors.teal,
            flexibleSpace: FlexibleSpaceBar(
              background: FutureBuilder<List<String>>(
                future: _imagesFuture,
                builder: (ctx, snap) {
                  final imgs = snap.data ?? [];
                  if (imgs.isEmpty) return Container(color: Colors.grey.shade200);
                  return PageView.builder(
                    itemCount: imgs.length,
                    itemBuilder: (_, i) => Image.network(imgs[i], fit: BoxFit.cover),
                  );
                },
              ),
            ),
          ),

          // 이름 + 공유 + 북마크
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.teal),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('공유 기능은 아직 구현되지 않았습니다.'))
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _bookmarked ? Icons.favorite : Icons.favorite_border,
                      color: _bookmarked ? Colors.red : Colors.grey,
                    ),
                    onPressed: () => setState(() => _bookmarked = !_bookmarked),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 예약현황 & 예약하기
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$dateLabel ${isAvail ? '예약 가능' : '예약 마감'} ($available/$total)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isAvail ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CampingReservationScreen(camp: camp)),
                      ),
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: const Text('예약 현황'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Colors.teal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (type == '국립') {
                        final uri = Uri.parse(
                            'https://reservation.knps.or.kr/reservation/searchSimpleCampReservation.do'
                        );
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                      else if (type == '지자체') {
                        final urlStr = camp['resveUrl'] as String? ?? '';
                        if (urlStr.isNotEmpty) {
                          final uri = Uri.parse(urlStr);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('예약 페이지를 열 수 없습니다.'))
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('예약 URL 정보가 없습니다.'))
                          );
                        }
                      }
                      else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('별도 예약 페이지가 없습니다.'))
                        );
                      }
                    },
                    child: const Text('예약하기'),
                  ),
                ),

                const Divider(height: 32),

                // 추가 정보
                InfoRow(label: '주소',        value: addr, icon: Icons.location_on,  iconColor: Colors.teal),
                InfoRow(label: '전화번호',    value: tel,  icon: Icons.phone,            iconColor: Colors.teal, onTap: () => _launchDialer(tel)),
                InfoRow(label: '캠핑장 유형', value: inDuty,icon: Icons.event_note,      iconColor: Colors.blueGrey),
                if (lctCl.isNotEmpty)
                  InfoRow(label: '환경',     value: lctCl, icon: Icons.nature,          iconColor: Colors.brown),

                const Divider(height: 32),

                // 부가시설
                const Text('부가시설', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (amenities.isEmpty)
                  Center(
                    child: Text(
                      '부가시설 정보가 없습니다.\n전화로 문의하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 16, runSpacing: 12,
                    children: displayedAmenities.map((am) {
                      final icon = _amenityIcons[am] ?? Icons.help_outline;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 32, color: Colors.teal),
                          const SizedBox(height: 4),
                          Text(am, style: const TextStyle(fontSize: 12)),
                        ],
                      );
                    }).toList(),
                  ),
                  if (amenities.length > 4)
                    TextButton(
                      onPressed: () => setState(() => _showAllAmenities = !_showAllAmenities),
                      child: Text(_showAllAmenities ? '접기' : '전체보기'),
                    ),
                ],

                const Divider(height: 32),

                // 상세 정보
                const Text('상세 정보', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('이곳에 해당 야영장의 시설 설명, 이용 요금, 부가 서비스 등을 표시할 수 있습니다.'),

                const Divider(height: 32),

                // 리뷰 작성
                const Text('리뷰 작성', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nicknameController,
                  decoration: InputDecoration(
                    labelText: '닉네임',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('평점:'),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _rating,
                      items: List.generate(5, (i) => i + 1).map((v) {
                        return DropdownMenuItem<int>(
                          value: v,
                          child: Text('$v'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() { _rating = v!; }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: '내용',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _submitReview,
                    child: const Text('등록'),
                  ),
                ),

                const Divider(height: 32),

                // 리뷰 목록
                const Text('후기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ReviewTile(nick: '익명', date: '2025-03-24', rating: 5, content: '캠핑장이 정말 깨끗하고 시설이 좋아요.'),
                ReviewTile(nick: '김철수', date: '2025-03-26', rating: 4, content: '주차 공간이 넓고 편리했어요.'),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String    label;
  final String    value;
  final IconData? icon;
  final Color?    iconColor;
  final VoidCallback? onTap;

  const InfoRow({
    Key? key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        if (icon != null) ...[
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 4),
        ],
        Expanded(child: Text(value)),
      ],
    );

    return onTap != null
        ? InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: content))
        : Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: content);
  }
}

class ReviewTile extends StatelessWidget {
  final String nick;
  final String date;
  final int rating;
  final String content;

  const ReviewTile({
    Key? key,
    required this.nick,
    required this.date,
    required this.rating,
    required this.content,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(nick, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (i) {
            return Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.green, size: 16);
          }),
        ),
        const SizedBox(height: 4),
        Text(content),
        const Divider(),
      ],
    );
  }
}
