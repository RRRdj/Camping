import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id; // userReview 문서 ID
  final String? contentId; // 캠핑장 contentId
  final String? campName; // 캠핑장 이름
  final String? content; // 후기 내용
  final int? rating; // 평점 1~5
  final Timestamp? date; // 작성일

  Review({
    required this.id,
    this.contentId,
    this.campName,
    this.content,
    this.rating,
    this.date,
  });

  factory Review.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    return Review(
      id: doc.id,
      contentId: m['contentId'] as String?,
      campName: m['campName'] as String?,
      content: m['content'] as String?,
      rating: m['rating'] as int?,
      date: m['date'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
    'contentId': contentId,
    'campName': campName,
    'content': content,
    'rating': rating,
    'date': date,
  };
}
