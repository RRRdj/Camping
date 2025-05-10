from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException
from webdriver_manager.chrome import ChromeDriverManager
import calendar
import time

import firebase_admin
from firebase_admin import credentials, firestore

# ──────────────────────────────────────────────────────────────────────────────
# Firebase 인증 및 초기화
cred = credentials.Certificate("camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

camp_name   = "불정 자연휴양림"
YEAR, MONTH = 2025, 5
START_DAY   = 9
total_seats = 28

# 이 달의 마지막 날짜 계산
_, last_day = calendar.monthrange(YEAR, MONTH)

# WebDriver 설정
options = webdriver.ChromeOptions()
# options.add_argument('--headless')  # 필요 시 주석 해제
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

availability = {}

for day in range(START_DAY, last_day + 1):
    date_str = f"{YEAR}-{MONTH:02d}-{day:02d}"
    url = f"https://www.mgtpcr.or.kr/web/forestSearch.do?searchDate={date_str}"
    driver.get(url)

    # ── tbody#list-area의 행 로딩 대기 ──
    try:
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.XPATH,
                "//tbody[@id='list-area']/tr"
            ))
        )
    except TimeoutException:
        print(f"{date_str} 테이블 로딩 실패 → available=0")
        availability[date_str] = {"available": 0, "total": total_seats}
        continue

    time.sleep(0.3)  # 렌더링 여유

    # ── “예약가능” 상태인 행 개수 세기 ──
    rows = driver.find_elements(By.XPATH, "//tbody[@id='list-area']/tr")
    available = 0
    for row in rows:
        status = row.find_element(By.XPATH, "./td[4]").text.strip()
        if status == "예약가능":
            available += 1

    availability[date_str] = {"available": available, "total": total_seats}
    print(f"{date_str} → available: {available}, total: {total_seats}")

# ── Firestore 업로드 & 최종 출력 ──
print("\n=== 최종 결과 ===")
for d, v in availability.items():
    print(f"{d} → {v}")

db.collection("realtime_availability") \
  .document(camp_name) \
  .set(availability, merge=True)

driver.quit()
