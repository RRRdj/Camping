from datetime import datetime
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

# 차단 요소 제거 대기 (필요 없으시면 비워두셔도 됩니다)
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
# options.add_argument('--headless')  # 필요 시 주석 해제
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

# ──────────────────────────────────────────────────────────────────────────────
# 1) 단호산단캠핑장 예약 페이지 열기
driver.get("https://www.danhosand.or.kr:1002/coding/sub4/sub2.asp")
time.sleep(2)  # 페이지 로딩 대기

camp_name = "단호샌드파크 자동차야영장"
availability_data = {}
today = datetime.today()
year, month = today.year, today.month

# ──────────────────────────────────────────────────────────────────────────────
# 2) 1일부터 31일까지 반복
for day in range(1, 32):
    # (A') 날짜 셀 전체
    # 예: <strong>7</strong> 이 들어있는 td를 찾아라
    CELL_XPATH_PARENT = (
        "//*[@id='contentDiv']//td"
        f"[.//strong[text()='{day}']]"
    )

    # ↑ 여기 [td[4]] 대신, 각 날짜 열 인덱스를 계산해서 넣으세요

    try:
        cell = WebDriverWait(driver, 5).until(
            EC.presence_of_element_located((By.XPATH, CELL_XPATH_PARENT))
        )
        # 디버깅: 셀 HTML 확인
        # print(cell.get_attribute("innerHTML"))

        # (B') 상대 경로로 "예약가능" 아이콘 찾기
        blue_boxes = cell.find_elements(By.XPATH, ".//img[@alt='예약가능']")
        avail = len(blue_boxes)

        date_str = datetime(year, month, day).strftime("%Y-%m-%d")
        availability_data[date_str] = {"available": avail, "total": 25}
        print(f"{date_str} → available: {avail}, total: 25")

    except Exception as e:
        # print(f"{day}일 실패: {e}")
        continue

# ──────────────────────────────────────────────────────────────────────────────
# 3) Firestore에 업로드
try:
    doc_ref = db.collection("realtime_availability").document(camp_name)
    doc_ref.set(availability_data, merge=True)
    print("✅ Firestore 업로드 완료")
except Exception as e:
    print(f"❌ Firestore 업로드 실패: {e}")

driver.quit()
