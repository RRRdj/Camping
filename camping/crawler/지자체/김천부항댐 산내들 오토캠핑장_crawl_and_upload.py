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
# options.add_argument('--headless')  # 필요 시 활성화
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

try:
    # 1) 산내들 캠핑장 예약 페이지 열기
    URL = "https://www.gc.go.kr/sannaedeul/programs/campSite/campSiteReserve.do?mId=0305000000"
    driver.get(URL)
    # 달력 로드 대기: 최소 5월 9일 셀(id="daynum_09")이 나올 때까지
    start_day = 9
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.ID, f"daynum_{start_day:02d}"))
    )
    time.sleep(0.5)

    # 2) 날짜 범위 계산
    today     = datetime.today()
    year      = today.year
    month     = today.month
    last_day  = calendar.monthrange(year, month)[1]
    # 5월 9일부터 시작
    start = max(start_day, today.day)

    camp_name   = "김천부항댐 산내들 오토캠핑장"
    total_seats = 52

    # 3) 결과 초기화
    availability = {
        f"{year}-{month:02d}-{d:02d}": {"available": 0, "total": total_seats}
        for d in range(start, last_day + 1)
    }

    # 4) 날짜별로 클릭 후 "예약하기" 링크(a[@title='예약하기']) 개수 카운트
    for day in range(start, last_day + 1):
        date_str = f"{year}-{month:02d}-{day:02d}"
        day_id    = f"daynum_{day:02d}"
        print(f"\n[{date_str}] 클릭 시도 → id={day_id}")

        # (A) 날짜 클릭
        try:
            cell = WebDriverWait(driver, 5).until(
                EC.element_to_be_clickable((By.ID, day_id))
            )
            driver.execute_script("arguments[0].click();", cell)
            time.sleep(0.5)
        except TimeoutException:
            print(f" → {date_str} 날짜 요소 미발견, available=0")
            continue

        # (B) 테이블 로드 대기
        try:
            WebDriverWait(driver, 5).until(
                EC.presence_of_element_located((By.XPATH,
                    "//*[@id='ctn']/div[2]/table/tbody/tr"
                ))
            )
        except TimeoutException:
            print(f" → {date_str} 테이블 미발견, available=0")
            continue

        # (C) '예약하기' title을 가진 <a> 태그만 선택
        links = driver.find_elements(By.XPATH,
            "//*[@id='ctn']/div[2]/table/tbody/tr/td[4]/a[@title='예약하기']"
        )
        avail = len(links)
        availability[date_str]["available"] = avail
        print(f" → available={avail}, total={total_seats}")

    # 5) Firestore에 업로드
    for d, v in availability.items():
        print(f"{d} → {v}")
    db.collection("realtime_availability") \
      .document(camp_name) \
      .set(availability, merge=True)

finally:
    driver.quit()
