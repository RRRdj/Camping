import 'package:flutter/material.dart';
import '../repositories/camp_image_repository.dart';
import '../services/static_data_service.dart';

class CampingSitesPage extends StatefulWidget {
  const CampingSitesPage({super.key});

  @override
  State<CampingSitesPage> createState() => _CampingSitesPageState();
}

class _CampingSitesPageState extends State<CampingSitesPage> {
  final _repo = CampImageRepository();
  final Map<String, String> _imageUrls = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initImages();
  }

  Future<void> _initImages() async {
    _imageUrls.addAll(await _repo.fetchImageUrls(StaticDataService.contentIds));
    if (mounted) setState(() => _loading = false);
  }

  String _img(String id) {
    if (_loading) return StaticDataService.placeholder('Loading');
    return _imageUrls[id]?.isNotEmpty == true
        ? _imageUrls[id]!
        : StaticDataService.placeholder();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
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
          onPressed:
              () =>
                  Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
        ),
      ],
    ),
    body: Column(
      children: [
        _searchBar(context),
        _filterTags(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              children: [
                _campCard(
                  id: '362',
                  location: '경북 구미시',
                  stars: 180,
                  name: '구미 캠핑장',
                  type: '지자체야영장',
                  available: true,
                  onTap: () => Navigator.pushNamed(context, '/camping_info'),
                ),
                const SizedBox(height: 10),
                _campCard(
                  id: '363',
                  location: '경북 영주시',
                  stars: 10,
                  name: '소백산삼가야영장',
                  type: '국립공원 야영장',
                  available: false,
                ),
                const SizedBox(height: 10),
                _campCard(
                  id: '364',
                  location: '경북 구미시',
                  stars: 60,
                  name: '구미 금오산야영장',
                  type: '지자체야영장',
                  available: true,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  /* ---------------- 위젯 빌더 ---------------- */

  Widget _searchBar(BuildContext ctx) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
              padding: EdgeInsets.only(left: 16),
              child: Text(
                '구미',
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black54),
            onPressed: () => Navigator.pushNamed(ctx, '/search_result'),
          ),
        ],
      ),
    ),
  );

  Widget _filterTags() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Row(
        children:
            StaticDataService.regions
                .map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _tag(t),
                  ),
                )
                .toList(),
      ),
    ),
  );

  Widget _tag(String txt) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Text('#$txt', style: const TextStyle(fontSize: 14)),
  );

  Widget _campCard({
    required String id,
    required String location,
    required int stars,
    required String name,
    required String type,
    required bool available,
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                _img(id),
                width: 75,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      width: 75,
                      height: 56,
                      color: Colors.grey,
                      child: const Icon(Icons.error, color: Colors.red),
                    ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(location, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, color: Colors.amber, size: 12),
                    Text(' $stars', style: const TextStyle(fontSize: 12)),
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
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                available ? '예약 가능' : '예약 마감',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
