from datetime import datetime
import calendar
import re
import time
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException
from webdriver_manager.chrome import ChromeDriverManager
import firebase_admin
from firebase_admin import credentials, firestore

# ──────────────────────────────────────────────────────────────────────────────
# Firebase init
cred = credentials.Certificate("camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# WebDriver setup
options = webdriver.ChromeOptions()
# options.add_argument('--headless')  # 필요 시 주석 해제
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

# 1) 페이지 열기
driver.get("https://stay.yd.go.kr/pages/sub.htm?nav_code=gor1501675800")
WebDriverWait(driver, 10).until(
    EC.presence_of_element_located((By.CSS_SELECTOR, "#body_content table"))
)
time.sleep(1)

camp_name = "영덕 고래불 국민 야영장"
availability_data = {}

# 오늘, 이번 달, 시작일, 마지막일
today      = datetime.today()
year, month = today.year, today.month
start_day  = today.day
last_day   = calendar.monthrange(year, month)[1]

# 2) today부터 마지막일까지 순회
for day in range(start_day, last_day + 1):
    # (A) “날짜”를 표시하는 <span>을 찾는 XPath
    span_xpath = (
        f"//*[@id='body_content']/table/tbody//span"
        f"[normalize-space()='{day}']"
    )
    try:
        # 날짜 span 요소 대기 후 가져오기
        span_elem = WebDriverWait(driver, 5).until(
            EC.presence_of_element_located((By.XPATH, span_xpath))
        )
        # (B) 그 span이 속한 <td> 셀을 상위로 찾아 올라가기
        cell = span_elem.find_element(By.XPATH, "./ancestor::td[1]")

        # (C) 셀 텍스트로 “예약마감”이 있는지 확인
        text = cell.text
        if "예약마감" in text:
            avail = 0
        else:
            # (D) 괄호 안 숫자 모두 추출·합산
            nums = re.findall(r'\((\d+)\)', text)
            avail = sum(int(n) for n in nums) if nums else 0

    except TimeoutException:
        # span을 못 찾았거나 로딩 실패 시
        avail = 0
    except Exception:
        # 기타 예외 시에도 0으로 처리
        avail = 0

    # (E) 결과 저장
    date_str = datetime(year, month, day).strftime("%Y-%m-%d")
    availability_data[date_str] = {"available": avail, "total": 152}
    print(f"{date_str} → available: {avail}, total: 152")

# 3) Firestore에 업로드
try:
    db.collection("realtime_availability") \
      .document(camp_name) \
      .set(availability_data, merge=True)
    print("✅ Firestore 업로드 완료")
except Exception as e:
    print("❌ 업로드 실패:", e)

driver.quit()
