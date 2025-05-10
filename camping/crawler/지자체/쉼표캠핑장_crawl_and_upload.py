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
    # 1) 페이지 열기 & 달력 로드 대기
    URL = "http://www.gumi-camping.co.kr/bbs/board.php?bo_table=reservation"
    driver.get(URL)
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.ID, "wrap-calendar"))
    )
    time.sleep(0.5)

    # 2) 오늘과 이달 마지막 날 계산
    today     = datetime.today()
    year      = today.year
    month     = today.month
    start_day = today.day
    last_day  = calendar.monthrange(year, month)[1]

    camp_name   = "쉼표캠핑장"
    total_seats = 11

    # 3) 결과 dict 초기화
    availability = {
        f"{year}-{month:02d}-{d:02d}": {"available": 0, "total": total_seats}
        for d in range(start_day, last_day + 1)
    }

    # 4) 달력의 모든 날짜 셀(td) 순회
    #    tbody[2] 에 각 주(week)가 있고 td마다 날짜 div, 그 안에 예(span) 요소가 있음
    rows = driver.find_elements(By.XPATH, "//*[@id='wrap-calendar']/table/tbody[2]/tr")
    for tr in rows:
        tds = tr.find_elements(By.TAG_NAME, "td")
        for td in tds:
            # 날짜 번호를 담은 <div>
            try:
                day_div = td.find_element(By.TAG_NAME, "div")
                day_text = day_div.text.strip()
                if not day_text.isdigit():
                    continue
                d = int(day_text)
            except:
                continue

            if d < start_day or d > last_day:
                continue

            date_str = f"{year}-{month:02d}-{d:02d}"
            # 예 박스(span) 셀렉터: ul/li/a/span[1]
            spans = td.find_elements(By.XPATH, ".//ul/li/a/span[1]")
            avail = len(spans)
            availability[date_str]["available"] = avail
            print(f"{date_str} → available: {avail}, total: {total_seats}")

    # 5) Firestore에 업로드
    for d, v in availability.items():
        print(f"{d} → {v}")
    db.collection("realtime_availability") \
      .document(camp_name) \
      .set(availability, merge=True)

finally:
    driver.quit()
