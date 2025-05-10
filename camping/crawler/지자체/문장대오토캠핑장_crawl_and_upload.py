from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException
from webdriver_manager.chrome import ChromeDriverManager
import calendar
import re
import time

import firebase_admin
from firebase_admin import credentials, firestore

# ──────────────────────────────────────────────────────────────────────────────
# Firebase 인증 및 초기화
cred = credentials.Certificate("camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

camp_name   = "문장대오토캠핑장"
URL         = "https://www.mjdcamp.kr:455/reservation.asp?location=002"
total_seats = 29
YEAR, MONTH = 2025, 5

# 이 달의 마지막 일 계산
_, last_day = calendar.monthrange(YEAR, MONTH)

# WebDriver 설정
options = webdriver.ChromeOptions()
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

# 1) 페이지 열기 + 팝업 닫기
driver.get(URL)
time.sleep(1)
try:
    driver.find_element(By.XPATH, "/html/body/div/div[2]/a").click()
    time.sleep(0.5)
except NoSuchElementException:
    pass

# 2) 달력 & 컨트롤 로딩 대기
WebDriverWait(driver, 10).until(
    EC.presence_of_element_located((By.XPATH,
        "//*[@id='contents']/div[2]/table"
    ))
)
WebDriverWait(driver, 10).until(
    EC.presence_of_element_located((By.ID, "util_select"))
)
time.sleep(0.5)

# 3) availability 초기화
availability = {
    f"{YEAR}-{MONTH:02d}-{day:02d}": {"available": 0, "total": total_seats}
    for day in range(1, last_day+1)
}

# 4) 옵션별 반복 (option[1]~option[7])
for opt_index in range(1, 8):
    # 4-1) 드롭다운에서 옵션 선택
    WebDriverWait(driver, 5).until(
        EC.element_to_be_clickable((By.ID, "util_select"))
    )
    driver.find_element(
        By.XPATH,
        f"//*[@id='util_select']/option[{opt_index}]"
    ).click()
    # 4-2) 조회 버튼 클릭
    driver.find_element(
        By.XPATH,
        "//*[@id='contents']/div[2]/div[2]/form/fieldset/input[3]"
    ).click()

    # 4-3) 테이블 로딩 대기
    try:
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.XPATH,
                "//*[@id='contents']/div[2]/table/tbody/tr/td"
            ))
        )
    except TimeoutException:
        print(f"옵션 {opt_index} 테이블 로딩 실패, 건너뜁니다")
        continue
    time.sleep(0.3)

    # 4-4) 각 날짜 셀 순회하며 이미지 개수 합산
    cells = driver.find_elements(
        By.XPATH,
        "//*[@id='contents']/div[2]/table/tbody//td"
    )
    for cell in cells:
        text = cell.text.strip()
        m = re.match(r"^(\d+)", text)
        if not m:
            continue
        day = int(m.group(1))
        if day < 1 or day > last_day:
            continue

        imgs = cell.find_elements(By.XPATH, ".//img[@alt='캠핑장']")
        availability[f"{YEAR}-{MONTH:02d}-{day:02d}"]["available"] += len(imgs)

# 5) 결과 업로드 & 출력
print("\n=== 최종 결과 ===")
for date_str, vals in availability.items():
    print(f"{date_str} → {vals}")

db.collection("realtime_availability") \
  .document(camp_name) \
  .set(availability, merge=True)

driver.quit()
