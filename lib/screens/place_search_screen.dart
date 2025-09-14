import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/place.dart';
import '../widgets/place_bookmark_sheet.dart';

class PlaceSearchScreen extends StatefulWidget {
  final void Function(String placeName, double lat, double lng)
  onLocationChange;

  const PlaceSearchScreen({super.key, required this.onLocationChange});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final String _kakaoApiKey = 'KakaoAK 59c53ddc8562ff7fb9d1716d4cb1d080';

  List<Place> _suggestions = [];
  List<Place> _bookmarks = [];
  Place? _home;
  bool _isLoading = false;

  final _addrCache = <String, String>{};

  Future<String> _getAddress(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    if (_addrCache.containsKey(key)) return _addrCache[key]!;
    final uri = Uri.parse(
      'https://dapi.kakao.com/v2/local/geo/coord2address.json?x=$lng&y=$lat',
    );
    final res = await http.get(uri, headers: {'Authorization': _kakaoApiKey});
    if (res.statusCode == 200) {
      final docs = json.decode(res.body)['documents'] as List;
      final addr =
      docs.isNotEmpty
          ? docs[0]['address']['address_name'] as String
          : '주소 정보 없음';
      _addrCache[key] = addr;
      return addr;
    }
    return '주소 정보 없음';
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _bookmarks =
        (prefs.getStringList('bookmarks') ?? [])
            .map(Place.fromJsonString)
            .toList();
    final h = prefs.getString('home');
    if (h != null) _home = Place.fromJsonString(h);
    setState(() {});
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'bookmarks',
      _bookmarks.map((p) => p.toJsonString()).toList(),
    );
  }

  Future<void> _saveHome(Place p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home', p.toJsonString());
  }

  bool _isBookmarked(Place p) => _bookmarks.any((b) => b.name == p.name);

  Future<void> _toggleBookmark(Place p) async {
    setState(() {
      _isBookmarked(p)
          ? _bookmarks.removeWhere((b) => b.name == p.name)
          : _bookmarks.add(p);
    });
    await _saveBookmarks();
  }

  Future<void> _setAsHome(Place p) async {
    setState(() => _home = p);
    await _saveHome(p);
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions.clear());
      return;
    }
    setState(() => _isLoading = true);

    final uri = Uri.parse(
      'https://dapi.kakao.com/v2/local/search/keyword.json?query=${Uri.encodeComponent(query)}',
    );
    final res = await http.get(uri, headers: {'Authorization': _kakaoApiKey});

    if (res.statusCode == 200) {
      final docs = json.decode(res.body)['documents'] as List;
      _suggestions = await Future.wait(
        docs.take(5).map((e) async {
          final lat = double.parse(e['y']);
          final lng = double.parse(e['x']);
          final addr = await _getAddress(lat, lng);
          return Place(
            name: e['place_name'],
            latitude: lat,
            longitude: lng,
            address: addr,
          );
        }),
      );
    } else {
      _suggestions.clear();
    }
    setState(() => _isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showBookmarkSheet() {
    final parentCtx = context;
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => PlaceBookmarkSheet(
        initialBookmarks: List<Place>.from(_bookmarks),
        initialHome: _home,
        onToggleBookmark: (p) async {
          await _toggleBookmark(p);
        },
        onSetHome: (p) async {
          await _setAsHome(p);
          widget.onLocationChange(p.name, p.latitude, p.longitude);

          final banner = MaterialBanner(
            content: Text('${p.name}이(가) 현위치로 지정되었습니다'),
            leading: const Icon(Icons.home, color: Colors.teal),
            backgroundColor:
            Theme.of(parentCtx).colorScheme.surfaceContainerHighest,
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(
                    parentCtx,
                  ).hideCurrentMaterialBanner();
                },
                child: const Text('닫기'),
              ),
            ],
          );

          final messenger = ScaffoldMessenger.of(parentCtx);
          messenger.showMaterialBanner(banner);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('장소 검색')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: '장소 이름을 입력하세요',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon:
                      _isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _suggestions.clear());
                        },
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) => _searchPlaces(v.trim()),
                    onChanged: (v) => _searchPlaces(v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                  onPressed: _showBookmarkSheet,
                  child: const Icon(Icons.star),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_suggestions.isNotEmpty)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.separated(
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final place = _suggestions[i];
                      final bookmarked = _isBookmarked(place);
                      return ListTile(
                        title: Text(place.name),
                        subtitle: Text(
                          place.address ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            bookmarked ? Icons.star : Icons.star_border,
                            color: bookmarked ? Colors.amber : Colors.grey,
                          ),
                          onPressed: () async {
                            await _toggleBookmark(place);
                            setState(() {});
                          },
                        ),
                        onTap: () {
                          widget.onLocationChange(
                            place.name,
                            place.latitude,
                            place.longitude,
                          );
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
