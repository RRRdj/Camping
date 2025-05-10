// upload_campgrounds.js
// 실행행 명령어 node upload_campgrounds.js
const admin = require('firebase-admin');
// 1) 서비스 계정 키 로드
const serviceAccount = require('./camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json');
// 2) JSON 데이터 로드
const campgrounds = require('./campground_data.json');

// 3) Firebase Admin 초기화
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// 4) Firestore 인스턴스 가져오기
const db = admin.firestore();

async function uploadCampgrounds() {
  // batch 쓰기를 사용하면 속도와 요금 절약
  const batch = db.batch();

  campgrounds.forEach(camp => {
    // 문서 ID는 캠핑장 이름(name)으로
    const docRef = db.collection('campgrounds').doc(camp.name);
    batch.set(docRef, camp);
  });

  await batch.commit();
  console.log(`✅ 총 ${campgrounds.length}개 캠핑장 업로드 완료`);
}

uploadCampgrounds().catch(err => {
  console.error('❌ 업로드 중 에러 발생:', err);
});
