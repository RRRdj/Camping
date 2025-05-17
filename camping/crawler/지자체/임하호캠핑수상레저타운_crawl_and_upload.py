from datetime import datetime
import calendar
import time
import re
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
import firebase_admin
from firebase_admin import credentials, firestore

# 0) Firebase 초기화
cred = credentials.Certificate("camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# 1) WebDriver 설정 및 리스트 페이지 열기
options = webdriver.ChromeOptions()
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

LISTING_URL = "https://booking.naver.com/booking/3/bizes/244686/items"
driver.get(LISTING_URL)

FIRST_ITEM_XPATH = "//*[@id='root']/div[2]/div[2]/div/ul/li[1]"
WebDriverWait(driver, 10).until(
    EC.presence_of_element_located((By.XPATH, FIRST_ITEM_XPATH))
)
time.sleep(1)

camp_name = "임하호 수상레저타운캠핑장"
today = datetime.today()
year, month = today.year, today.month
last_day = calendar.monthrange(year, month)[1]

# 2) 날짜별 available 합산 초기화
availability = {
    datetime(year, month, d).strftime("%Y-%m-%d"): 0
    for d in range(1, last_day + 1)
}

# 3) 각 아이템 페이지 순회하면서 날짜 버튼 상태 확인
for idx in range(1, 44):
    item_xpath = f"//*[@id='root']/div[2]/div[2]/div/ul/li[{idx}]/a"
    link = WebDriverWait(driver, 10).until(
        EC.element_to_be_clickable((By.XPATH, item_xpath))
    )
    driver.execute_script("arguments[0].click();", link)

    # 달력 버튼 로드 대기
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.XPATH, "//button[contains(@class,'calendar_date')]"))
    )
    time.sleep(1)

    # 모든 날짜 버튼 수집
    buttons = driver.find_elements(By.XPATH, "//button[contains(@class,'calendar_date')]")
    for btn in buttons:
        txt = btn.text.strip()
        if not txt.isdigit():
            continue
        day = int(txt)
        if day < 1 or day > last_day:
            continue

        cls = btn.get_attribute("class") or ""
        avail_this = 0 if "unselectable" in cls else 1

        date_str = datetime(year, month, day).strftime("%Y-%m-%d")
        availability[date_str] += avail_this

    # 뒤로 가기 및 첫 아이템 재로딩
    driver.back()
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.XPATH, FIRST_ITEM_XPATH))
    )
    time.sleep(0.5)

# 4) Firestore에 날짜별 {available, total} 형태로 업로드
TOTAL_ITEMS = 43  # 전체 아이템 수

upload_data = {}
for date_str, count in availability.items():
    upload_data[date_str] = {
        'available': count,
        'total': TOTAL_ITEMS,
    }
    print(f"{date_str} → available: {count}, total: {TOTAL_ITEMS}")

db.collection("realtime_availability") \
  .document(camp_name) \
  .set(upload_data, merge=True)

driver.quit()
