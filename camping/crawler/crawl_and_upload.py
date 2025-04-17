from datetime import datetime, timedelta
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
import firebase_admin
from firebase_admin import credentials, firestore
import time

# Firebase 인증 정보 설정
cred = credentials.Certificate("camping-8ae8b-firebase-adminsdk-fbsvc-90708e1d14.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# 내일 날짜 설정
target_date = datetime.today() + timedelta(days=1)
month_str = f"{target_date.month:02d}"
day_str = f"{target_date.day:02d}"
display_date = target_date.strftime('%Y-%m-%d')
element_id = f"RCCnt{month_str}{day_str}"

campgrounds = ['백운동', '삼정', '치인']

# Selenium WebDriver 설정
options = webdriver.ChromeOptions()
# options.add_argument('--headless')  # 디버깅 시 주석처리
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)

driver.get("https://res.knps.or.kr/reservation/searchSimpleCampReservation.do")

# 가야산 클릭
WebDriverWait(driver, 10).until(
    EC.element_to_be_clickable((By.XPATH, "//a[contains(text(), '가야산')]"))
).click()
time.sleep(1)

# 각 캠핑장 반복
for name in campgrounds:
    print(f"📍 {name} | {display_date} | ", end="")

    # 캠핑장 클릭 시도
    try:
        WebDriverWait(driver, 5).until(
            EC.element_to_be_clickable((By.XPATH, f"//a[contains(text(), '{name}')]"))
        ).click()
        time.sleep(2)
    except Exception as e:
        print(f"❌ 클릭 실패: {e}")
        continue

    # 전체 자리 수 추출
    try:
        total_xpath = '//*[@id="tab14-5"]/div[4]/div[1]/table[2]/thead/tr[3]/td[1]'
        total_sites = WebDriverWait(driver, 5).until(
            EC.presence_of_element_located((By.XPATH, total_xpath))
        ).text
    except:
        total_sites = "0"

    # 예약 가능 자리 수 추출
    try:
        available = WebDriverWait(driver, 5).until(
            EC.presence_of_element_located((By.ID, element_id))
        ).text
        print(f"예약 가능: {available} / 전체: {total_sites}")
    except:
        print("❌ 예약 가능 수 추출 실패")
        continue

    # Firestore 업로드
    try:
        db.collection("realtime_availability").document(name).set({
            "date": display_date,
            "available": int(available),
            "total": int(total_sites)
        })
        print(f"✅ 업로드 완료: {name} ({available}/{total_sites})")
    except Exception as e:
        print(f"❌ Firestore 업로드 실패: {e}")

driver.quit()
