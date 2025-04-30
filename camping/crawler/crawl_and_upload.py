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

# 차단 요소 제거 대기
def wait_for_unblock(driver):
    for blocker_id in ["loadingImage", "BackMask", "netFu"]:
        try:
            WebDriverWait(driver, 5).until(EC.invisibility_of_element_located((By.ID, blocker_id)))
        except:
            continue

# 클릭 함수 (재시도 1회 + 수동 대기 포함)
def safe_click(driver, xpath):
    for attempt in range(2):
        try:
            wait_for_unblock(driver)
            WebDriverWait(driver, 15).until(EC.presence_of_element_located((By.XPATH, xpath)))
            element = WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, xpath)))
            time.sleep(1.5)
            driver.execute_script("arguments[0].click();", element)
            return True
        except Exception as e:
            if attempt == 1:
                print(f"❌ XPath 클릭 실패: {xpath} | {e}")
                return False
            time.sleep(1.5)

# Selenium WebDriver 설정
options = webdriver.ChromeOptions()
# options.add_argument('--headless')
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)

driver.get("https://res.knps.or.kr/reservation/searchSimpleCampReservation.do")

campground_info = {'계룡산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[2]/a', 'campgrounds': {'갑사': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[2]/div/ul/li[1]/a', '동학사': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[2]/div/ul/li[2]/a'}}, '내장산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[3]/a', 'campgrounds': {'가인': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[3]/div/ul/li[1]/a', '내장': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[3]/div/ul/li[2]/a', '내장호': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[3]/div/ul/li[3]/a'}}, '다도해해상': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[4]/a', 'campgrounds': {'구계등': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[4]/div/ul/li[1]/a', '염포': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[4]/div/ul/li[2]/a', '팔영산': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[4]/div/ul/li[3]/a'}}, '덕유산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[1]/a', 'campgrounds': {'덕유대1': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[1]/div/ul/li[1]/a', '덕유대2': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[1]/div/ul/li[2]/a', '덕유대3': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[1]/div/ul/li[3]/a'}}, '무등산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[2]/a', 'campgrounds': {'도원': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[2]/div/ul/li/a'}}, '변산반도': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[3]/a', 'campgrounds': {'고사포1': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[3]/div/ul/li[1]/a', '고사포2': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[3]/div/ul/li[2]/a'}}, '북한산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[4]/a', 'campgrounds': {'사기막': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[4]/div/ul/li/a'}}, '설악산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[1]/a', 'campgrounds': {'설악동': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[1]/div/ul/li/a'}}, '소백산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[2]/a', 'campgrounds': {'남천': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[2]/div/ul/li[1]/a', '삼가': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[2]/div/ul/li[2]/a'}}, '오대산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[3]/a', 'campgrounds': {'소금강산': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[3]/div/ul/li/a'}}, '월악산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/a', 'campgrounds': {'닷돈재1': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/div/ul/li[1]/a', '닷돈재2': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/div/ul/li[2]/a', '덕주': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/div/ul/li[3]/a', '송계': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/div/ul/li[4]/a', '용하': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/div/ul/li[5]/a', '하선암': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/div/ul/li[6]/a'}}, '월출산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[1]/a', 'campgrounds': {'천황': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[1]/div/ul/li/a'}}, '주왕산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[2]/a', 'campgrounds': {'상의': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[2]/div/ul/li/a'}}, '지리산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/a', 'campgrounds': {'내원': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[1]/a', '달궁1': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[2]/a', '달궁2': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[3]/a', '덕동': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[4]/a', '백무동': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[5]/a', '뱀사골1': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[6]/a', '뱀사골2': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[7]/a', '소막골': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[8]/a', '학천': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[9]/a'}}, '치악산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[4]/a', 'campgrounds': {'구룡': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[4]/div/ul/li[1]/a', '금대': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[4]/div/ul/li[2]/a'}}, '태백산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[1]/a', 'campgrounds': {'소도': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[1]/div/ul/li/a'}}, '태안해안': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[2]/a', 'campgrounds': {'몽산포': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[2]/div/ul/li[1]/a', '학암포': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[2]/div/ul/li[2]/a'}}, '팔공산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[3]/a', 'campgrounds': {'갓바위': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[3]/div/ul/li[1]/a', '도학': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[3]/div/ul/li[2]/a'}}, '한려해상': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[4]/a', 'campgrounds': {'덕신': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[4]/div/ul/li[1]/a', '학동': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[4]/div/ul/li[2]/a'}}, '가야산': {'xpath': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[1]/a', 'campgrounds': {'백운동': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[1]/div/ul/li[1]/a', '삼정': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[1]/div/ul/li[2]/a', '치인': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[1]/div/ul/li[3]/a'}}}


for park, data in campground_info.items():
    park_xpath = data["xpath"]
    print(f"▶ 공원 클릭: {park}")
    if not safe_click(driver, park_xpath):
        continue
    time.sleep(2.5)

    for camp, camp_xpath in data["campgrounds"].items():
        print(f"\n==== {park} - {camp} 크롤링 시작 ====")
        if not safe_click(driver, camp_xpath):
            continue
        time.sleep(2)

        # 전체 자리수는 날짜 반복 전에 한 번만 수집
        try:
            total_xpath = '//*[@id="tab14-5"]/div[4]/div[1]/table[2]/thead/tr[3]/td[1]'
            total_sites = WebDriverWait(driver, 5).until(
                EC.presence_of_element_located((By.XPATH, total_xpath))
            ).text
            total_sites = int(total_sites)
        except:
            total_sites = 0

        availability_data = {}
        for i in range(1, 6):
            target_date = datetime.today() + timedelta(days=i)
            month_str = f"{target_date.month:02d}"
            day_str = f"{target_date.day:02d}"
            display_date = target_date.strftime('%Y-%m-%d')
            element_id = f"RCCnt{month_str}{day_str}"

            print(f"📍 {display_date} | ", end="")
            try:
                available = WebDriverWait(driver, 5).until(
                    EC.presence_of_element_located((By.ID, element_id))
                ).text
                print(f"예약 가능: {available} / 전체: {total_sites}")
            except:
                print("❌ 예약 가능 수 추출 실패")
                continue

            availability_data[display_date] = {
                "available": int(available),
                "total": total_sites
            }

        try:
            doc_ref = db.collection("realtime_availability").document(camp)
            doc_ref.set(availability_data, merge=True)
            print(f"✅ Firestore 업로드 완료 ({len(availability_data)}일치)")
        except Exception as e:
            print(f"❌ Firestore 업로드 실패: {e}")

driver.quit()
