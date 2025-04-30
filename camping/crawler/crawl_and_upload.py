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

campgrounds = ['백운동', '삼정', '치인']

# Selenium WebDriver 설정
options = webdriver.ChromeOptions()
# options.add_argument('--headless')  # 디버깅 시 비활성화
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)

driver.get("https://res.knps.or.kr/reservation/searchSimpleCampReservation.do")

# 가야산 클릭
WebDriverWait(driver, 10).until(
    EC.element_to_be_clickable((By.XPATH, "//a[contains(text(), '가야산')]"))
).click()
time.sleep(1)

# 각 캠핑장 반복
for name in campgrounds:
    print(f"\n=== {name} 크롤링 시작 ===")

    # 캠핑장 클릭
    try:
        WebDriverWait(driver, 5).until(
            EC.element_to_be_clickable((By.XPATH, f"//a[contains(text(), '{name}')]"))
        ).click()
        time.sleep(2)
    except Exception as e:
        print(f"❌ 캠핑장 클릭 실패: {e}")
        continue

    # 날짜별 정보 저장용 딕셔너리
    availability_data = {}

    for i in range(1, 6):  # 내일부터 5일간
        target_date = datetime.today() + timedelta(days=i)
        month_str = f"{target_date.month:02d}"
        day_str = f"{target_date.day:02d}"
        display_date = target_date.strftime('%Y-%m-%d')
        element_id = f"RCCnt{month_str}{day_str}"

        print(f"📍 {display_date} | ", end="")

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

        # 날짜별 데이터 저장
        availability_data[display_date] = {
            "available": int(available),
            "total": int(total_sites)
        }

    # Firestore에 업로드 (기존 데이터 유지, 날짜만 갱신)
    try:
        doc_ref = db.collection("realtime_availability").document(name)
        doc_ref.set(availability_data, merge=True)
        print(f"✅ Firestore 업로드 완료 ({len(availability_data)}일치)")
    except Exception as e:
        print(f"❌ Firestore 업로드 실패: {e}")

driver.quit()
