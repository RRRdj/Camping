import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String? contentId;
  final String? campName;
  final String? content;
  final int? rating;
  final Timestamp? date;

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
