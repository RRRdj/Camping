import 'package:flutter/material.dart';

String wmoKoText(int? code) {
  switch (code) {
    case 0:
      return '맑음';
    case 1:
    case 2:
      return '부분적 흐림';
    case 3:
      return '흐림';
    case 45:
    case 48:
      return '안개';
    case 51:
    case 53:
    case 55:
      return '이슬비';
    case 61:
    case 63:
    case 65:
      return '비';
    case 71:
    case 73:
    case 75:
      return '눈';
    case 80:
    case 81:
    case 82:
      return '소나기';
    case 95:
      return '천둥번개';
    case 96:
    case 99:
      return '뇌우(우박)';
    default:
      return '날씨';
  }
}

IconData wmoIcon(int? code) {
  if (code == null) return Icons.wb_cloudy;
  if (code == 0) return Icons.wb_sunny;
  if (code == 3) return Icons.cloud;
  if ([1, 2].contains(code)) return Icons.cloud_queue;
  if ([61, 63, 65, 80, 81, 82].contains(code)) return Icons.water_drop;
  if ([71, 73, 75].contains(code)) return Icons.ac_unit;
  if ([95, 96, 99].contains(code)) return Icons.thunderstorm;
  if ([45, 48].contains(code)) return Icons.blur_on;
  if ([51, 53, 55].contains(code)) return Icons.grain;
  return Icons.wb_cloudy;
}

/// PM10 / PM2.5 기준으로 등급 반환
String krGradePm10(double v) {
  if (v <= 30) return '좋음';
  if (v <= 80) return '보통';
  if (v <= 150) return '나쁨';
  return '매우 나쁨';
}

String krGradePm25(double v) {
  if (v <= 15) return '좋음';
  if (v <= 35) return '보통';
  if (v <= 75) return '나쁨';
  return '매우 나쁨';
}

/// PM10 / PM2.5 수치를 받아 한 줄 요약 텍스트 생성
String? airLine(double? pm10, double? pm25) {
  if (pm10 == null && pm25 == null) return null;
  final parts = <String>[];
  if (pm10 != null) {
    parts.add('PM10 ${pm10.toStringAsFixed(0)}㎍/㎥ (${krGradePm10(pm10)})');
  }
  if (pm25 != null) {
    parts.add('PM2.5 ${pm25.toStringAsFixed(0)}㎍/㎥ (${krGradePm25(pm25)})');
  }
  return parts.join(' · ');
}
