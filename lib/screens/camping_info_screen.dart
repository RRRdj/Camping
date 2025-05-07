import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'camping_reservation_screen.dart';

class CampingInfoScreen extends StatefulWidget {
  final Map<String, dynamic> camp;
  const CampingInfoScreen({super.key, required this.camp});
  @override
  State<CampingInfoScreen> createState() => _CampingInfoScreenState();
}

class _CampingInfoScreenState extends State<CampingInfoScreen> {
  static const _serviceKey =
      'aL18yks/TuI52tnTlLaQJMx9YCVO0R+vqXjDZBmBe3ST78itxBjo6ZKJIvlWWSh2tTqkWFpbpELlGrCuKFlUaw==';
  late Future<List<String>> _images;
  bool _bookmarked = false;
  final _nickCtr = TextEditingController();
  final _txtCtr = TextEditingController();
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _images = _fetchImages();
  }

  Future<List<String>> _fetchImages() async {
    final uri = Uri.parse(
      'https://apis.data.go.kr/B551011/GoCamping/imageList',
    ).replace(
      queryParameters: {
        'serviceKey': _serviceKey,
        'contentId': widget.camp['contentId'],
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
    final urls =
        doc
            .findAllElements('imageUrl')
            .map((e) => e.text.trim())
            .where((u) => u.isNotEmpty)
            .toList();
    final first = widget.camp['firstImageUrl'] as String? ?? '';
    if (first.isNotEmpty && !urls.contains(first)) urls.insert(0, first);
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.camp;
    final dateLabel = DateFormat(
      'MM월 dd일',
    ).format(DateTime.now().add(const Duration(days: 1)));
    final isAvail = (c['available'] as int? ?? 0) > 0;
    final amenities = (c['amenities'] as List<dynamic>?)?.cast<String>() ?? [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _HeaderImages(images: _images),
          SliverToBoxAdapter(
            child: _TitleBar(
              name: c['name'],
              bookmarked: _bookmarked,
              onToggle: () => setState(() => _bookmarked = !_bookmarked),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ReservationBar(
                  dateLabel: dateLabel,
                  isAvail: isAvail,
                  available: c['available'],
                  total: c['total'],
                  camp: c,
                ),
                const Divider(height: 32),
                _InfoSection(camp: c, onDial: _launchDialer),
                const Divider(height: 32),
                _AmenitySection(amenities: amenities),
                const Divider(height: 32),
                _DetailSection(),
                const Divider(height: 32),
                _ReviewForm(
                  nickCtr: _nickCtr,
                  txtCtr: _txtCtr,
                  rating: _rating,
                  onRating: (v) => setState(() => _rating = v),
                  onSubmit: _submitReview,
                ),
                const Divider(height: 32),
                _ReviewList(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchDialer(String num) async {
    final uri = Uri(scheme: 'tel', path: num);
    if (await canLaunchUrl(uri))
      await launchUrl(uri);
    else
      _showMsg('전화 앱을 열 수 없습니다.');
  }

  void _submitReview() {
    if (_nickCtr.text.trim().isEmpty || _txtCtr.text.trim().isEmpty)
      return _showMsg('닉네임과 내용을 입력하세요.');
    _nickCtr.clear();
    _txtCtr.clear();
    setState(() => _rating = 5);
    _showMsg('리뷰가 등록되었습니다.');
  }

  void _showMsg(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class _HeaderImages extends StatelessWidget {
  final Future<List<String>> images;
  const _HeaderImages({required this.images});
  @override
  Widget build(BuildContext context) => SliverAppBar(
    pinned: true,
    expandedHeight: 250,
    backgroundColor: Colors.teal,
    flexibleSpace: FlexibleSpaceBar(
      background: FutureBuilder<List<String>>(
        future: images,
        builder: (_, snap) {
          final imgs = snap.data ?? [];
          if (imgs.isEmpty) return Container(color: Colors.grey.shade200);
          return PageView.builder(
            itemCount: imgs.length,
            itemBuilder: (_, i) => Image.network(imgs[i], fit: BoxFit.cover),
          );
        },
      ),
    ),
  );
}

class _TitleBar extends StatelessWidget {
  final String name;
  final bool bookmarked;
  final VoidCallback onToggle;
  const _TitleBar({
    required this.name,
    required this.bookmarked,
    required this.onToggle,
  });
  @override
  Widget build(BuildContext context) => Padding(
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
          onPressed:
              () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('공유 기능 준비중'))),
        ),
        IconButton(
          icon: Icon(
            bookmarked ? Icons.favorite : Icons.favorite_border,
            color: bookmarked ? Colors.red : Colors.grey,
          ),
          onPressed: onToggle,
        ),
      ],
    ),
  );
}

class _ReservationBar extends StatelessWidget {
  final String dateLabel;
  final bool isAvail;
  final int available, total;
  final Map<String, dynamic> camp;
  const _ReservationBar({
    required this.dateLabel,
    required this.isAvail,
    required this.available,
    required this.total,
    required this.camp,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
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
            icon: const Icon(Icons.calendar_today_outlined),
            label: const Text('예약 현황'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.teal,
              side: const BorderSide(color: Colors.teal),
            ),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampingReservationScreen(camp: camp),
                  ),
                ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _openExternal(context),
          child: const Text('예약하기'),
        ),
      ),
    ],
  );

  Future<void> _openExternal(BuildContext context) async {
    final type = camp['type'];
    String? url;
    if (type == '국립')
      url =
          'https://reservation.knps.or.kr/reservation/searchSimpleCampReservation.do';
    else if (type == '지자체')
      url = camp['resveUrl'];
    if (url == null || url.isEmpty) return _msg(context, '예약 페이지가 없습니다.');
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    else
      _msg(context, '페이지를 열 수 없습니다.');
  }

  void _msg(BuildContext ctx, String m) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(m)));
}

class _InfoSection extends StatelessWidget {
  final Map<String, dynamic> camp;
  final void Function(String) onDial;
  const _InfoSection({required this.camp, required this.onDial});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _InfoRow(
        label: '주소',
        value: camp['addr1'] ?? '정보없음',
        icon: Icons.location_on,
        color: Colors.teal,
      ),
      _InfoRow(
        label: '전화번호',
        value: camp['tel'] ?? '정보없음',
        icon: Icons.phone,
        color: Colors.teal,
        onTap: () => onDial(camp['tel']),
      ),
      _InfoRow(
        label: '캠핑장 유형',
        value: camp['inDuty'] ?? '정보없음',
        icon: Icons.event_note,
        color: Colors.blueGrey,
      ),
      if ((camp['lctCl'] ?? '').isNotEmpty)
        _InfoRow(
          label: '환경',
          value: camp['lctCl'],
          icon: Icons.nature,
          color: Colors.brown,
        ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Expanded(child: Text(value)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: onTap != null ? InkWell(onTap: onTap, child: row) : row,
    );
  }
}

class _AmenitySection extends StatefulWidget {
  final List<String> amenities;
  const _AmenitySection({required this.amenities});
  @override
  State<_AmenitySection> createState() => _AmenitySectionState();
}

class _AmenitySectionState extends State<_AmenitySection> {
  bool _showAll = false;
  static const _icons = {
    '전기': Icons.flash_on,
    '무선인터넷': Icons.wifi,
    '장작판매': Icons.local_fire_department,
    '온수': Icons.hot_tub,
    '트램플린': Icons.sports,
    '물놀이장': Icons.pool,
    '놀이터': Icons.child_friendly,
    '산책로': Icons.directions_walk,
    '운동시설': Icons.fitness_center,
    '마트.편의점': Icons.store,
  };
  @override
  Widget build(BuildContext context) {
    final ams = widget.amenities;
    if (ams.isEmpty)
      return Center(
        child: Text(
          '부가시설 정보가 없습니다.\n전화로 문의하세요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    final list = !_showAll && ams.length > 4 ? ams.take(4) : ams;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '부가시설',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children:
              list
                  .map(
                    (am) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _icons[am] ?? Icons.help_outline,
                          size: 32,
                          color: Colors.teal,
                        ),
                        const SizedBox(height: 4),
                        Text(am, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  )
                  .toList(),
        ),
        if (ams.length > 4)
          TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(_showAll ? '접기' : '전체보기'),
          ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: const [
      Text(
        '상세 정보',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 8),
      Text('이곳에 해당 야영장의 시설 설명, 이용 요금, 부가 서비스 등을 표시할 수 있습니다.'),
    ],
  );
}

class _ReviewForm extends StatelessWidget {
  final TextEditingController nickCtr, txtCtr;
  final int rating;
  final ValueChanged<int> onRating;
  final VoidCallback onSubmit;
  const _ReviewForm({
    required this.nickCtr,
    required this.txtCtr,
    required this.rating,
    required this.onRating,
    required this.onSubmit,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '리뷰 작성',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: nickCtr,
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
            value: rating,
            items: [
              for (var v in List.generate(5, (i) => i + 1))
                DropdownMenuItem(value: v, child: Text('$v')),
            ],
            onChanged: (int? newValue) {
              if (newValue == null) return;
              onRating(newValue);
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: txtCtr,
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
        child: ElevatedButton(onPressed: onSubmit, child: const Text('등록')),
      ),
    ],
  );
}

class _ReviewList extends StatelessWidget {
  const _ReviewList();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: const [
      Text('후기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      _ReviewTile(
        nick: '익명',
        date: '2025-03-24',
        rating: 5,
        content: '캠핑장이 정말 깨끗하고 시설이 좋아요.',
      ),
      _ReviewTile(
        nick: '김철수',
        date: '2025-03-26',
        rating: 4,
        content: '주차 공간이 넓고 편리했어요.',
      ),
    ],
  );
}

class _ReviewTile extends StatelessWidget {
  final String nick, date, content;
  final int rating;
  const _ReviewTile({
    required this.nick,
    required this.date,
    required this.rating,
    required this.content,
  });
  @override
  Widget build(BuildContext context) => Column(
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
        children: List.generate(
          5,
          (i) => Icon(
            i < rating ? Icons.star : Icons.star_border,
            color: Colors.green,
            size: 16,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(content),
      const Divider(),
    ],
  );
}
