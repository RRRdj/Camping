from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException
from webdriver_manager.chrome import ChromeDriverManager
import time

import firebase_admin
from firebase_admin import credentials, firestore

# ──────────────────────────────────────────────────────────────────────────────
# 1) Firebase 인증 및 초기화
cred = credentials.Certificate("camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# ──────────────────────────────────────────────────────────────────────────────
# 2) WebDriver 설정
options = webdriver.ChromeOptions()
# options.add_argument('--headless')  # 필요 시 화면 없이 실행
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

# ──────────────────────────────────────────────────────────────────────────────
URL         = "http://www.93camp.kr/main/sub.html?pageCode=8"
camp_name   = "구산오토캠핑장"
total_seats = 25

# 연·월 (원하는 월로 고정)
YEAR, MONTH = 2025, 5

# 1) 페이지 열고 캘린더 로딩 대기
driver.get(URL)
try:
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.ID, "psCalendar"))
    )
except TimeoutException:
    print("❌ 캘린더 로딩 실패")
    driver.quit()
    exit()

time.sleep(1)  # 추가 렌더링 대기

# 2) 모든 날짜 셀(<td>) 수집
date_cells = driver.find_elements(By.XPATH, "//div[@id='psCalendar']//table//td")
print(f"🔍 날짜 셀 총 {len(date_cells)}개 검사")

availability = {}
for cell in date_cells:
    # 첫 번째 <p> 태그에서 텍스트(날짜) 읽기
    p_tags = cell.find_elements(By.TAG_NAME, "p")
    if not p_tags:
        continue
    day_text = p_tags[0].text.strip()
    if not day_text.isdigit():
        continue

    day = int(day_text)
    date_str = f"{YEAR}-{MONTH:02d}-{day:02d}"

    # calendar_001.png 아이콘 개수 세기
    cnt = 0
    imgs = cell.find_elements(By.TAG_NAME, "img")
    for img in imgs:
        src = img.get_attribute("src") or ""
        if src.endswith("calendar_001.png"):
            cnt += 1

    availability[date_str] = {
        "available": cnt,
        "total":     total_seats
    }
    print(f"{date_str} → available: {cnt}, total: {total_seats}")

# 3) Firestore 업로드 및 결과 출력
print("\n=== 최종 업로드 전 확인 ===")
for d, v in availability.items():
    print(f"{d} → {v}")

db.collection("realtime_availability") \
  .document(camp_name) \
  .set(availability, merge=True)

print("\n✅ Firestore 저장 완료!")

driver.quit()
