// lib/services/format_service.dart

import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 날짜·별점·리뷰 등 화면용 포맷팅을 모두 담당합니다.
class FormatService {
  /// AlarmManageScreen 등에서 쓰는 알림 날짜 포맷
  String alarmDate(DateTime d) => DateFormat('yyyy년 M월 d일').format(d);

  /// 리뷰 리스트에서 Timestamp 또는 DateTime을 깔끔히 보여줄 때
  String reviewDate(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
    }
    if (ts is DateTime) {
      return DateFormat('yyyy-MM-dd HH:mm').format(ts);
    }
    return ts?.toString().substring(0, 16) ?? '';
  }

  /// 평점 레이블 (★5 등)
  String ratingLabel(int? r) => '★${r ?? 5}';
}
