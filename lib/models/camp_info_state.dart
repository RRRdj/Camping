class CampInfoState {
  final Map<String, dynamic> camp;
  final List<String> images;
  final String? contentId;
  final int available;
  final int total;
  final bool isBookmarked;
  CampInfoState({
    required this.camp,
    required this.images,
    required this.contentId,
    required this.available,
    required this.total,
    required this.isBookmarked,
  });
}
