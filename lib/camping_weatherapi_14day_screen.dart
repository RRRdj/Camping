// camping_weatherapi_14day_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CampingWeatherAPI14DayScreen extends StatefulWidget {
  final double lat;
  final double lng;

  const CampingWeatherAPI14DayScreen({
    super.key,
    required this.lat,
    required this.lng,
  });

  @override
  State<CampingWeatherAPI14DayScreen> createState() => _CampingWeatherAPI14DayScreenState();
}

class _CampingWeatherAPI14DayScreenState extends State<CampingWeatherAPI14DayScreen> {
  List<WeatherDay> _forecast = [];
  bool _isLoading = true;
  String? _error;
  String? _lastQuery;

  // 간단 캐시(앱 구동 중 유지)
  static final Map<String, List<WeatherDay>> _cache = {};

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  @override
  void didUpdateWidget(covariant CampingWeatherAPI14DayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lng != widget.lng) {
      _fetchWeather();
    }
  }

  Future<void> _fetchWeather() async {
    final query = '${widget.lat.toStringAsFixed(4)},${widget.lng.toStringAsFixed(4)}';
    if (_lastQuery == query && _forecast.isNotEmpty) return;
    _lastQuery = query;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final String wxUrl =
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${widget.lat.toStringAsFixed(4)}'
        '&longitude=${widget.lng.toStringAsFixed(4)}'
        '&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_mean'
        '&forecast_days=14'
        '&timezone=auto';

    // 캐시 히트 시 즉시 표시 후 백그라운드 갱신
    if (_cache.containsKey(query)) {
      setState(() {
        _forecast = _cache[query]!;
        _isLoading = false;
      });
      _refreshFromNetwork(wxUrl, query);
      return;
    }

    await _refreshFromNetwork(wxUrl, query);
  }

  Future<void> _refreshFromNetwork(String wxUrl, String query) async {
    try {
      // 1) 날씨(일별)
      final wxResp = await http.get(Uri.parse(wxUrl)).timeout(const Duration(seconds: 8));
      if (wxResp.statusCode != 200) {
        return _setHttpError(wxResp.statusCode);
      }
      final wxDecoded = utf8.decode(wxResp.bodyBytes);
      final wxBody = json.decode(wxDecoded) as Map<String, dynamic>;

      final List times = (wxBody['daily']?['time'] as List?) ?? [];
      final List codes = (wxBody['daily']?['weathercode'] as List?) ?? [];
      final List tmax  = (wxBody['daily']?['temperature_2m_max'] as List?) ?? [];
      final List tmin  = (wxBody['daily']?['temperature_2m_min'] as List?) ?? [];
      final List prcp  = (wxBody['daily']?['precipitation_probability_mean'] as List?) ?? [];

      // 날짜 범위 (공기질 쿼리용)
      final String startDate = times.isEmpty ? _todayString() : (times.first as String);
      final String endDate   = times.isEmpty ? _plusDaysString(13) : (times.last as String);

      // 2) 공기질(시간별 → 날짜별 집계)
      final aqUrl =
          'https://air-quality-api.open-meteo.com/v1/air-quality'
          '?latitude=${widget.lat.toStringAsFixed(4)}'
          '&longitude=${widget.lng.toStringAsFixed(4)}'
          '&hourly=pm10,pm2_5,us_aqi'   // ✅ us_aqi 추가
          '&forecast_days=14'
          '&models=cams_global'
          '&timezone=auto';
      Map<String, AirDaily> aqDailyMap = {};
      try {
        final aqResp = await http.get(Uri.parse(aqUrl)).timeout(const Duration(seconds: 8));
        if (aqResp.statusCode == 200) {
          final aqDecoded = utf8.decode(aqResp.bodyBytes);
          final aqBody = json.decode(aqDecoded) as Map<String, dynamic>;
          aqDailyMap = _aggregateAirQualityDaily(aqBody); // 날짜별 평균 PM10/PM2.5 집계
        }
        // 공기질이 실패해도 날씨는 계속 표시
      } catch (_) {
        // ignore air quality failure
      }

      // 3) 합치기
      final int n = times.length;
      final List<WeatherDay> parsed = List.generate(n, (i) {
        final String date = (i < times.length) ? (times[i] as String? ?? '') : '';
        final int? wmo = (i < codes.length && codes[i] != null) ? (codes[i] as num).toInt() : null;
        final AirDaily? aq = aqDailyMap[date];

        return WeatherDay(
          date: date,
          condition: _wmoKoText(wmo),
          wmoCode: wmo,
          maxTempC: (i < tmax.length && tmax[i] != null) ? (tmax[i] as num).toDouble() : null,
          minTempC: (i < tmin.length && tmin[i] != null) ? (tmin[i] as num).toDouble() : null,
          dailyChanceOfRain: (i < prcp.length && prcp[i] != null) ? (prcp[i] as num).round() : null,
          pm10: aq?.pm10Mean,
          pm25: aq?.pm25Mean,
        );
      });

      if (!mounted) return;
      setState(() {
        _forecast = parsed;
        _isLoading = false;
      });
      _cache[query] = parsed;
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '네트워크 오류: ${e.runtimeType}';
        _isLoading = false;
      });
    }
  }

  void _setHttpError(int status) {
    final msg = switch (status) {
      400 => '요청이 올바르지 않습니다(400).',
      429 => '요청이 너무 많습니다(429). 잠시 후 다시 시도하세요.',
      500 || 502 || 503 => '날씨 서버가 불안정합니다($status).',
      _ => '오류가 발생했습니다($status).',
    };
    if (!mounted) return;
    setState(() {
      _error = msg;
      _isLoading = false;
    });
  }

  Future<void> _onRefresh() async {
    if (_lastQuery == null) return;
    final String wxUrl =
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${widget.lat.toStringAsFixed(4)}'
        '&longitude=${widget.lng.toStringAsFixed(4)}'
        '&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_mean'
        '&forecast_days=14'
        '&timezone=auto';

    await _refreshFromNetwork(wxUrl, _lastQuery!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2주 캠핑 날씨 & 미세먼지')),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _fetchWeather)
                : _forecast.isEmpty
                    ? const Center(child: Text('날씨 정보를 불러올 수 없습니다.'))
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _forecast.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final day = _forecast[index];
                          final airText = _buildAirLine(day.pm10, day.pm25);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: Icon(_wmoIcon(day.wmoCode), size: 32),
                              title: Text('${day.date} - ${day.condition ?? "날씨 정보 없음"}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '최고: ${day.maxTempC?.toStringAsFixed(1) ?? "-"}℃  /  '
                                    '최저: ${day.minTempC?.toStringAsFixed(1) ?? "-"}℃'
                                    '${day.dailyChanceOfRain != null ? '  •  강수확률 ${day.dailyChanceOfRain}%' : ''}',
                                  ),
                                  if (airText != null) ...[
                                    const SizedBox(height: 4),
                                    Text(airText, style: const TextStyle(fontSize: 12)),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

// ===== 도우미들 =====

String _todayString() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

String _plusDaysString(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// 시간별 공기질을 날짜별 평균으로 집계
Map<String, AirDaily> _aggregateAirQualityDaily(Map<String, dynamic> aqBody) {
  final times = (aqBody['hourly']?['time'] as List?) ?? [];
  final pm10  = (aqBody['hourly']?['pm10'] as List?) ?? [];
  final pm25  = (aqBody['hourly']?['pm2_5'] as List?) ?? [];

  final Map<String, _Agg> buckets = {};
  for (int i = 0; i < times.length; i++) {
    final String t = times[i] as String? ?? '';
    if (t.length < 10) continue;
    final String day = t.substring(0, 10); // yyyy-MM-dd
    final double? v10 = (i < pm10.length && pm10[i] != null) ? (pm10[i] as num).toDouble() : null;
    final double? v25 = (i < pm25.length && pm25[i] != null) ? (pm25[i] as num).toDouble() : null;

    buckets.putIfAbsent(day, () => _Agg());
    if (v10 != null) buckets[day]!.sum10 += v10;
    if (v25 != null) buckets[day]!.sum25 += v25;
    if (v10 != null) buckets[day]!.cnt10++;
    if (v25 != null) buckets[day]!.cnt25++;
  }

  final Map<String, AirDaily> out = {};
  buckets.forEach((date, agg) {
    out[date] = AirDaily(
      pm10Mean: agg.cnt10 > 0 ? agg.sum10 / agg.cnt10 : null,
      pm25Mean: agg.cnt25 > 0 ? agg.sum25 / agg.cnt25 : null,
    );
  });
  return out;
}

class _Agg {
  double sum10 = 0;
  double sum25 = 0;
  int cnt10 = 0;
  int cnt25 = 0;
}

class AirDaily {
  final double? pm10Mean;
  final double? pm25Mean;
  AirDaily({this.pm10Mean, this.pm25Mean});
}

/// 화면에 넣을 “미세먼지 한 줄”
String? _buildAirLine(double? pm10, double? pm25) {
  if (pm10 == null && pm25 == null) return null;
  final parts = <String>[];
  if (pm10 != null) {
    parts.add('PM10 ${pm10.toStringAsFixed(0)}㎍/㎥ (${_krGradePm10(pm10)})');
  }
  if (pm25 != null) {
    parts.add('PM2.5 ${pm25.toStringAsFixed(0)}㎍/㎥ (${_krGradePm25(pm25)})');
  }
  return parts.join(' · ');
}

/// 국내 기준(환경부) 대략적 구간
String _krGradePm10(double v) {
  if (v <= 30) return '좋음';
  if (v <= 80) return '보통';
  if (v <= 150) return '나쁨';
  return '매우 나쁨';
}

String _krGradePm25(double v) {
  if (v <= 15) return '좋음';
  if (v <= 35) return '보통';
  if (v <= 75) return '나쁨';
  return '매우 나쁨';
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class WeatherDay {
  final String date; // yyyy-MM-dd
  final String? condition;
  final int? wmoCode;
  final double? maxTempC;
  final double? minTempC;
  final int? dailyChanceOfRain;

  // 공기질(일평균)
  final double? pm10;  // ㎍/㎥
  final double? pm25;  // ㎍/㎥

  WeatherDay({
    required this.date,
    this.condition,
    this.wmoCode,
    this.maxTempC,
    this.minTempC,
    this.dailyChanceOfRain,
    this.pm10,
    this.pm25,
  });
}

/// WMO 코드 → 한글 설명(간단)
String _wmoKoText(int? code) {
  switch (code) {
    case 0:
      return '맑음';
    case 1:
    case 2:
      return '부분적으로 흐림';
    case 3:
      return '흐림';
    case 45:
    case 48:
      return '안개';
    case 51:
    case 53:
    case 55:
      return '이슬비';
    case 56:
    case 57:
      return '착설 이슬비';
    case 61:
    case 63:
    case 65:
      return '비';
    case 66:
    case 67:
      return '착설 비';
    case 71:
    case 73:
    case 75:
      return '눈';
    case 77:
      return '진눈깨비';
    case 80:
    case 81:
    case 82:
      return '소나기';
    case 85:
    case 86:
      return '소낙눈';
    case 95:
      return '천둥번개';
    case 96:
    case 99:
      return '뇌우(우박)';
    default:
      return '날씨 정보';
  }
}

/// WMO 코드 → 머터리얼 아이콘
IconData _wmoIcon(int? code) {
  if (code == null) return Icons.wb_cloudy;
  if (code == 0) return Icons.wb_sunny;               // 맑음
  if ([1, 2].contains(code)) return Icons.cloud_queue; // 부분 흐림
  if (code == 3) return Icons.cloud;                   // 흐림
  if ([61, 63, 65, 80, 81, 82].contains(code)) return Icons.water_drop; // 비/소나기
  if ([71, 73, 75, 85, 86].contains(code)) return Icons.ac_unit;        // 눈
  if ([95, 96, 99].contains(code)) return Icons.thunderstorm;           // 뇌우
  if ([45, 48].contains(code)) return Icons.blur_on;                    // 안개
  return Icons.wb_cloudy;
}
