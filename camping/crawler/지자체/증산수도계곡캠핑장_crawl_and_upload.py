from datetime import datetime
import calendar
import time
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
import firebase_admin
from firebase_admin import credentials, firestore
from selenium.common.exceptions import TimeoutException

# ──────────────────────────────────────────────────────────────────────────────
# Firebase 인증 및 초기화
cred = credentials.Certificate("camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# ──────────────────────────────────────────────────────────────────────────────
# WebDriver 설정
options = webdriver.ChromeOptions()
# options.add_argument('--headless')
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

try:
    # 1) 수돗골캠핑장 예약 페이지 열기
    URL = "https://www.gc.go.kr/sudo/programs/campSite/campSiteReserve.do?mId=0304000000"
    driver.get(URL)

    # 2) 초기 클릭: 5월 9일(daynum_09) 선택해야 테이블이 로드됩니다
    WebDriverWait(driver, 10).until(
        EC.element_to_be_clickable((By.ID, "daynum_09"))
    ).click()
    time.sleep(0.5)

    # 3) 오늘부터 이달 말일까지 날짜 계산
    today    = datetime.today()
    year     = today.year
    month    = today.month
    last_day = calendar.monthrange(year, month)[1]

    camp_name   = "증산수도계곡캠핑장"
    total_seats = 27

    # 4) 결과 dict 초기화 (오늘부터 월말까지)
    start_day = today.day
    availability = {
        f"{year}-{month:02d}-{d:02d}": {"available": 0, "total": total_seats}
        for d in range(start_day, last_day+1)
    }

    # 5) 날짜별로 클릭 → 예약하기 링크 개수 카운트
    for day in range(start_day, last_day+1):
        date_str = f"{year}-{month:02d}-{day:02d}"
        day_id   = f"daynum_{day:02d}"
        print(f"\n[{date_str}] 날짜 클릭 시도 → id={day_id}")

        # (A) 날짜 클릭
        try:
            WebDriverWait(driver, 5).until(
                EC.element_to_be_clickable((By.ID, day_id))
            ).click()
            time.sleep(0.3)
        except TimeoutException:
            print(f" → {date_str} 날짜 요소 미발견, available=0")
            continue

        # (B) 예약 테이블 로드 대기
        try:
            WebDriverWait(driver, 5).until(
                EC.presence_of_element_located((By.XPATH,
                    "//*[@id='sub_cont']/div[2]/table/tbody/tr"
                ))
            )
        except TimeoutException:
            print(f" → {date_str} 테이블 로드 실패, available=0")
            continue

        # (C) 모든 tr의 td[4]/a 예약하기 링크 개수 세기
        links = driver.find_elements(By.XPATH,
            "//*[@id='sub_cont']/div[2]/table/tbody/tr/td[4]/a"
        )
        avail = len(links)
        availability[date_str]["available"] = avail
        print(f" → available={avail}, total={total_seats}")

    # 6) Firestore에 업로드
    for d, v in availability.items():
        print(f"{d} → {v}")
    db.collection("realtime_availability") \
      .document(camp_name) \
      .set(availability, merge=True)

finally:
    driver.quit()
