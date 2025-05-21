import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/camp_repository.dart';
import '../models/camp_info_state.dart';

final campRepositoryProvider = Provider((ref) => CampRepository());

/// 파라미터를 묶은 키
class CampInfoKey {
  final String campName;
  final int available;
  final int total;
  final bool isBookmarked;
  CampInfoKey(this.campName, this.available, this.total, this.isBookmarked);
}

/// VM : 캠핑장 정보 + 이미지 + 사용자 닉네임
final campInfoProvider = FutureProvider.family<CampInfoState, CampInfoKey>((
  ref,
  key,
) async {
  final repo = ref.watch(campRepositoryProvider);

  final doc = await repo.campgroundDoc(key.campName);
  final data = doc.data()!;
  final contentId = data['contentId']?.toString();
  final images = await repo.campImages(contentId ?? '', data['firstImageUrl']);

  return CampInfoState(
    camp: data,
    images: images,
    contentId: contentId,
    available: key.available,
    total: key.total,
    isBookmarked: key.isBookmarked,
  );
});

/// 로그인한 사용자의 닉네임
final userNicknameProvider = FutureProvider<String?>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  return ref.watch(campRepositoryProvider).userNickname(uid);
});
