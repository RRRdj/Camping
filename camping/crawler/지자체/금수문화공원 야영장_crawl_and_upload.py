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

camp_name   = "금수문화공원 야영장"
URL         = "https://www.sj.go.kr/gumsu/page.do?mnu_uid=1850&self"
total_seats = 100

# 크롤링할 연·월
YEAR, MONTH = 2025, 5
_, last_day = calendar.monthrange(YEAR, MONTH)

# WebDriver 설정
options = webdriver.ChromeOptions()
# options.add_argument('--headless')
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

# 1) 페이지 열기
driver.get(URL)
time.sleep(1)

# 2) 팝업 또는 초기 버튼 클릭 (//*[@id="frm"]/div[2]/a)
try:
    WebDriverWait(driver, 5).until(
        EC.element_to_be_clickable((By.XPATH, "//*[@id='frm']/div[2]/a"))
    ).click()
    time.sleep(0.5)
except (TimeoutException, NoSuchElementException):
    pass

# 3) 달력 로딩 대기
WebDriverWait(driver, 10).until(
    EC.presence_of_element_located((By.XPATH,
        "//*[@id='frm']/div/div[1]/div[1]/table"
    ))
)
time.sleep(0.5)

# 4) 날짜 링크 수집
date_links = driver.find_elements(By.XPATH,
    "//*[@id='frm']/div/div[1]/div[1]/table//td/a"
)
days = [int(a.text.strip()) for a in date_links if a.text.strip().isdigit()]

availability = {}

# 5) 각 날짜별 반복
for day in days:
    date_str = f"{YEAR}-{MONTH:02d}-{day:02d}"

    # 5-1) 다시 메인 페이지로 돌아가서 반드시 팝업버튼 클릭
    driver.get(URL)
    time.sleep(0.5)
    try:
        driver.find_element(By.XPATH, "//*[@id='frm']/div[2]/a").click()
        time.sleep(0.5)
    except NoSuchElementException:
        pass

    # 5-2) 달력 로딩 대기
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.XPATH,
            "//*[@id='frm']/div/div[1]/div[1]/table"
        ))
    )
    time.sleep(0.3)

    # 5-3) 해당 날짜 클릭
    try:
        driver.find_element(By.LINK_TEXT, str(day)).click()
    except NoSuchElementException:
        availability[date_str] = {"available": 0, "total": total_seats}
        print(f"{date_str} → 클릭 실패, available=0")
        continue

    # 5-4) 예약 테이블 로딩 대기
    try:
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.XPATH,
                "//*[@id='frm']/div/div[2]/table"
            ))
        )
    except TimeoutException:
        availability[date_str] = {"available": 0, "total": total_seats}
        print(f"{date_str} → 테이블 로딩 실패, available=0")
        continue
    time.sleep(0.3)

    # 5-5) 예약하기 링크 개수 세기
    links = driver.find_elements(By.XPATH,
        "//*[@id='frm']/div/div[2]/table/tbody//tr/td[6]/a[text()='예약하기']"
    )
    available = len(links)
    availability[date_str] = {"available": available, "total": total_seats}
    print(f"{date_str} → available: {available}, total: {total_seats}")

# 6) Firestore 업로드 & 최종 결과 출력
print("\n=== 최종 결과 ===")
for d, v in availability.items():
    print(f"{d} → {v}")

db.collection("realtime_availability") \
  .document(camp_name) \
  .set(availability, merge=True)

driver.quit()
