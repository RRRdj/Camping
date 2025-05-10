from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
import calendar
import time
import re

import firebase_admin
from firebase_admin import credentials, firestore

# ──────────────────────────────────────────────────────────────────────────────
# Firebase 인증 및 초기화
cred = credentials.Certificate("camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

camp_name   = "봉화열목어마을"
URL         = "https://www.bhtown.kr/board/reserv/reservation_status.php?type=0"
YEAR, MONTH = 2025, 6     # 페이지 기본이 6월이므로
START_DAY   = 1
total_seats = 13

# 해당 달의 마지막 일
_, last_day = calendar.monthrange(YEAR, MONTH)

# WebDriver 설정
options = webdriver.ChromeOptions()
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

availability = {}

# 1) 페이지 열기
driver.get(URL)
time.sleep(1)  # 전체 렌더링 대기
html = driver.page_source

# 2) day 별로 블록 잘라내서 파싱
for day in range(START_DAY, last_day+1):
    date_str = f"{YEAR}-{MONTH:02d}-{day:02d}"

    # 다음 날짜 헤더를 미리 계산
    next_day = day+1
    # 정규식: "21일" 부터 "22일" 전까지
    pattern = rf"{day}일[\s\S]*?(?={next_day}일|$)"
    m = re.search(pattern, html)
    if not m:
        # 블록을 못 찾으면 0 처리
        available = 0
    else:
        block = m.group(0)
        # 블록 내 '가' 표시 개수 세기 (예약가능 글자)
        ga_count = len(re.findall(r"가", block))
        # 블록 내 <span>숫자</span> 값 합산
        spans = re.findall(r"<span>(\d+)</span>", block)
        span_sum = sum(int(x) for x in spans)
        available = ga_count + span_sum

    availability[date_str] = {
        "available": available,
        "total":     total_seats
    }
    print(f"{date_str} → available: {available}, total: {total_seats}")

# 3) Firestore 에 업로드 & 결과 출력
for d, v in availability.items():
    print(f"{d} → {v}")

db.collection("realtime_availability") \
  .document(camp_name) \
  .set(availability, merge=True)

driver.quit()
