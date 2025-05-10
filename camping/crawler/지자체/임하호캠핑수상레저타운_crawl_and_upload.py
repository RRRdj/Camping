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

# Firebase init
cred = credentials.Certificate("camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# WebDriver setup
options = webdriver.ChromeOptions()
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)

# 1) 리스트 페이지 열기
LISTING_URL = "https://booking.naver.com/booking/3/bizes/244686/items"
driver.get(LISTING_URL)

# → 아래를 대체: 리스트 내 첫 번째 <li> 가 로드될 때까지 기다립니다
FIRST_ITEM_XPATH = "//*[@id='root']/div[2]/div[2]/div/ul/li[1]"
WebDriverWait(driver, 10).until(
    EC.presence_of_element_located((By.XPATH, FIRST_ITEM_XPATH))
)
time.sleep(1)

camp_name = "임하호 수상레저타운캠핑장"
today     = datetime.today()
year, month = today.year, today.month
last_day  = calendar.monthrange(year, month)[1]

# 날짜별 합산 초기화
availability = {
    datetime(year, month, d).strftime("%Y-%m-%d"): 0
    for d in range(1, last_day+1)
}

# 2) 아이템(1~43) 순회
for idx in range(1, 44):
    item_xpath = f"//*[@id='root']/div[2]/div[2]/div/ul/li[{idx}]/a"
    link = WebDriverWait(driver, 10).until(
        EC.element_to_be_clickable((By.XPATH, item_xpath))
    )
    driver.execute_script("arguments[0].click();", link)

    # 달력 버튼 로드 대기 (class 이름은 페이지 구조에 따라 바뀔 수 있음)
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.XPATH, "//button[contains(@class,'calendar_date')]"))
    )
    time.sleep(1)

    # 모든 날짜 버튼 수집
    buttons = driver.find_elements(By.XPATH, "//button[contains(@class,'calendar_date')]")
    for btn in buttons:
        txt = btn.text.strip()
        if not txt.isdigit(): continue
        day = int(txt)
        if day < 1 or day > last_day: continue

        cls = btn.get_attribute("class") or ""
        avail_this = 0 if "unselectable" in cls else 1

        date_str = datetime(year, month, day).strftime("%Y-%m-%d")
        availability[date_str] += avail_this

    # 뒤로 가기 후 리스트 첫 아이템 다시 대기
    driver.back()
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.XPATH, FIRST_ITEM_XPATH))
    )
    time.sleep(0.5)

# 3) Firestore 업로드
for d, v in availability.items():
    print(f"{d} → available: {v}, total: 43")

db.collection("realtime_availability") \
  .document(camp_name) \
  .set(availability, merge=True)

driver.quit()
