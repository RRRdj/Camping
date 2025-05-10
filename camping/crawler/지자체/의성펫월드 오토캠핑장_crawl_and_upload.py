from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException
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

# ──────────────────────────────────────────────────────────────────────────────
camp_name   = "의성펫월드 오토캠핑장"
YEAR, MONTH = 2025, 5
total_seats = 9
base_url    = "https://www.usc.go.kr/reserve/page.do?mnu_uid=2051&cate_uid=70"

# 이번 달의 마지막 날짜
_, last_day = calendar.monthrange(YEAR, MONTH)

# WebDriver 설정
options = webdriver.ChromeOptions()
# options.add_argument('--headless')
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

availability = {}

# 1) 기본 페이지 열고 달력 로딩 대기
driver.get(base_url)
WebDriverWait(driver, 10).until(
    EC.presence_of_element_located((By.XPATH,
        "//*[@id='sub_cont']/div[2]/div[1]"
    ))
)
time.sleep(0.5)

# 2) 달력에서 td 요소 순회하며 클릭 가능 날짜와 href 추출
cal_div = driver.find_element(By.XPATH, "//*[@id='sub_cont']/div[2]/div[1]")
cells  = cal_div.find_elements(By.TAG_NAME, "td")

day_to_href = {}
for cell in cells:
    # 안에 <a> 가 있으면 클릭 가능
    try:
        a = cell.find_element(By.TAG_NAME, "a")
        day = int(a.text.strip())
        href = a.get_attribute("href")
        day_to_href[day] = href
    except (NoSuchElementException, ValueError):
        # <a> 없거나 숫자로 변환 불가하면 건너뜀
        continue

# 3) 1일부터 마지막일까지 반복
for day in range(1, last_day + 1):
    date_str = f"{YEAR}-{MONTH:02d}-{day:02d}"

    if day not in day_to_href:
        # 클릭 불가한 날
        availability[date_str] = {"available": 0, "total": total_seats}
        print(f"{date_str} → 클릭 불가 → available: 0")
        continue

    # 4) 클릭 가능 날짜: href 로 페이지 로드
    driver.get(day_to_href[day])
    try:
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.XPATH,
                "//*[@id='sub_cont']/div[4]/table"
            ))
        )
    except TimeoutException:
        available = 0
    else:
        time.sleep(0.3)
        # 5) '예약하기' 링크 개수 세기
        links = driver.find_elements(
            By.XPATH,
            "//*[@id='sub_cont']/div[4]/table//a[@title='예약하기']"
        )
        available = len(links)

    availability[date_str] = {"available": available, "total": total_seats}
    print(f"{date_str} → available: {available}")

# 6) Firestore 업로드 & 결과 출력
for d, v in availability.items():
    print(f"{d} → {v}")

db.collection("realtime_availability") \
  .document(camp_name) \
  .set(availability, merge=True)

driver.quit()
