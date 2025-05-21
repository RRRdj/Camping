class CampWithAvailability {
  final Map<String, dynamic> camp; // 캠핑장 기본 정보
  final int available;
  final int total;

  CampWithAvailability({
    required this.camp,
    required this.available,
    required this.total,
  });

  bool get isAvailable => available > 0;
}
