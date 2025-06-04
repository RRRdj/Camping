import 'package:cloud_firestore/cloud_firestore.dart';

class AlarmModel {
  final String id;
  final String campName;
  final String contentId;
  final DateTime date;
  final bool isNotified;

  AlarmModel({
    required this.id,
    required this.campName,
    required this.contentId,
    required this.date,
    required this.isNotified,
  });

  factory AlarmModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlarmModel(
      id: doc.id,
      campName: data['campName'] ?? '',
      contentId: data['contentId'] ?? '',
      date: DateTime.parse(data['date']),
      isNotified: data['isNotified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'campName': campName,
    'contentId': contentId,
    'date': date.toIso8601String(),
    'isNotified': isNotified,
  };
}
