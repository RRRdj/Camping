from datetime import datetime, timedelta
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
import firebase_admin
from firebase_admin import credentials, firestore
import time

# ──────────────────────────────────────────────────────────────────────────────
# Firebase 인증 정보 설정
cred = credentials.Certificate("camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# 차단 요소 제거 대기
def wait_for_unblock(driver):
    for blocker_id in ["loadingImage", "BackMask", "netFu"]:
        try:
            WebDriverWait(driver, 5).until(
                EC.invisibility_of_element_located((By.ID, blocker_id))
            )
        except:
            continue

# Selenium WebDriver 설정
options = webdriver.ChromeOptions()
# options.add_argument('--headless')  # 필요 시 해제
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

# 구미시 금오캠핑장 예약 페이지 접속
driver.get("https://www.gumi.go.kr/reservation/www/geumocamp/list.do?key=116#n")
time.sleep(2)  # 페이지 로딩 대기

# ──────────────────────────────────────────────────────────────────────────────
camp = "금오산 야영장"
availability_data = {}

# 1일차부터 14일차까지 날짜별로 ar/rs ID 생성
for i in range(1, 15):
    target_date = datetime.today() + timedelta(days=i)
    ymd = target_date.strftime("%Y%m%d")          # "20250507"
    display_date = target_date.strftime("%Y-%m-%d")  # "2025-05-07"

    ar_id = f"ar{ymd}"  # 잔여 좌석 ID
    rs_id = f"rs{ymd}"  # 예약 완료 좌석 ID

    try:
        # 잔여 좌석 수
        ar_text = WebDriverWait(driver, 5).until(
            EC.presence_of_element_located((By.ID, ar_id))
        ).text
        ar_num = int(ar_text.replace("건", "").strip())

        # 예약 완료 좌석 수
        rs_text = driver.find_element(By.ID, rs_id).text
        rs_num  = int(rs_text.replace("건", "").strip())

        total = ar_num + rs_num

        availability_data[display_date] = {
            "available": ar_num,
            "total":     total
        }
        print(f"{display_date} → 잔여: {ar_num}건 / 전체: {total}건")

    except Exception as e:
        print(f"{display_date} → 데이터 추출 실패 ({e})")

# Firestore에 업로드
try:
    doc_ref = db.collection("realtime_availability").document(camp)
    doc_ref.set(availability_data, merge=True)
    print("✅ Firestore 업로드 완료")
except Exception as e:
    print(f"❌ Firestore 업로드 실패: {e}")

driver.quit()
