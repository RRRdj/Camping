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
# Firebase 인증 및 초기화
cred = credentials.Certificate("camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# ──────────────────────────────────────────────────────────────────────────────
camp_name    = "염전해변캠핑장"
URL          = "https://forest.maketicket.co.kr/ticket/GD110"
total_seats  = 31

# WebDriver 설정
options = webdriver.ChromeOptions()
# options.add_argument('--headless')  # 필요 시
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

# ── 1) 페이지 접속 & 팝업 닫기 ──
driver.get(URL)
try:
    btn_close = WebDriverWait(driver, 5).until(
        EC.element_to_be_clickable((By.XPATH, "/html/body/div/div[2]/a"))
    )
    btn_close.click()
except TimeoutException:
    pass
time.sleep(1)  # 팝업 닫히고 달력 렌더링 대기

# ── 2) 달력에서 날짜 요소 수집 ──
#    id가 "calendar_<숫자>" 패턴인 엘리먼트
date_elems = driver.find_elements(By.XPATH, "//*[starts-with(@id,'calendar_')]")

availability = {}

for elem in date_elems:
    date_id = elem.get_attribute("id")            # ex: "calendar_9"
    parts   = date_id.split("_", 1)
    if len(parts) != 2 or not parts[1].isdigit():
        continue
    day = int(parts[1])
    # 날짜 문자열 (년-월-일) – 필요에 따라 YEAR, MONTH 하드코딩 또는 파싱
    # 이 예제에선 YYYY-MM-DD 를 2025-05-DD로 고정
    date_str = f"2025-05-{day:02d}"

    # ── 3) 해당 날짜의 li[1], li[2] span 값을 더하기 ──
    available = 0
    try:
        span1 = elem.find_element(By.XPATH, "./ul/li[1]/a/span").text
        available += int(span1)
    except NoSuchElementException:
        pass
    try:
        span2 = elem.find_element(By.XPATH, "./ul/li[2]/a/span").text
        available += int(span2)
    except NoSuchElementException:
        pass

    availability[date_str] = {
        "available": available,
        "total":     total_seats
    }
    print(f"{date_str} → available: {available}, total: {total_seats}")

# ── 4) Firestore에 업로드 & 결과 출력 ──
for d, v in availability.items():
    print(f"{d} → {v}")

db.collection("realtime_availability") \
  .document(camp_name) \
  .set(availability, merge=True)

driver.quit()
