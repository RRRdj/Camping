from datetime import datetime
import calendar
import re
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
service = Service(ChromeDriverManager().install())
driver = webdriver.Chrome(service=service, options=options)

try:
    # 1) 페이지 열기 & 팝업 닫기
    driver.get("https://tickets.interpark.com/goods/20010339")
    try:
        popup_close = WebDriverWait(driver, 5).until(
            EC.element_to_be_clickable((By.XPATH,
                "//*[@id='popup-prdGuide']/div/div[3]/button"
            ))
        )
        driver.execute_script("arguments[0].click();", popup_close)
        time.sleep(0.3)
    except TimeoutException:
        pass

    # 2) 달력의 날짜 li 요소들 로드 대기
    OPT_LIS_XPATH = (
        "//*[@id='productSide']/div/div[1]/div[1]/div[2]/div/div/div/div/ul[3]/li"
    )
    lis = WebDriverWait(driver, 10).until(
        EC.presence_of_all_elements_located((By.XPATH, OPT_LIS_XPATH))
    )
    time.sleep(0.5)
    print(f"디버그: 총 날짜 li 개수 = {len(lis)}")

    # 3) 오늘부터 이달 말까지 날짜 범위
    today     = datetime.today()
    year      = today.year
    month     = today.month
    start_day = today.day
    last_day  = calendar.monthrange(year, month)[1]

    camp_name   = "치산 관광지 캠핑장"
    total_seats = 28

    # 4) 결과 딕셔너리 초기화
    availability = {
        f"{year}-{month:02d}-{d:02d}": {"available": 0, "total": total_seats}
        for d in range(start_day, last_day+1)
    }

    # 5) li.text(일 숫자) → day 매핑
    day_to_li = {}
    for li in lis:
        txt = li.text.strip()
        if txt.isdigit():
            d = int(txt)
            # today 이후, 이번 달 범위만
            if start_day <= d <= last_day:
                day_to_li[d] = li

    # 6) 순회하며 클릭 & span 합산
    for day in range(start_day, last_day+1):
        date_str = f"{year}-{month:02d}-{day:02d}"
        li = day_to_li.get(day)
        if not li:
            print(f"{date_str} → 날짜 li 없음, available=0")
            continue

        cls = li.get_attribute("class") or ""
        print(f"\n[{date_str}] li.text='{li.text}' class='{cls}'")

        # disabled 처리
        if "disabled" in cls or "unselectable" in cls:
            print(" → 예약불가 처리, available=0")
            continue

        # (A) 날짜 클릭
        driver.execute_script("arguments[0].scrollIntoView();", li)
        driver.execute_script("arguments[0].click();", li)
        time.sleep(0.3)

        # (B) 하단 span 로드 대기
        span_container = (
            "//*[@id='productSide']/div/div[1]/div[2]/div[2]/div[2]/ul/li[1]/span"
        )
        try:
            WebDriverWait(driver, 5).until(
                EC.presence_of_element_located((By.XPATH, span_container))
            )
        except TimeoutException:
            print(" → span 로드 실패, available=0")
            continue

        # (C) 세 개 span 합산
        avail = 0
        for i in (1, 2, 3):
            span_xpath = (
                f"//*[@id='productSide']/div/div[1]/div[2]/div[2]/div[2]/ul/li[{i}]/span"
            )
            try:
                span = driver.find_element(By.XPATH, span_xpath)
                num = int(re.sub(r"\D", "", span.text))
                print(f"  span[{i}]='{span.text}' → {num}")
                avail += num
            except Exception:
                print(f"  span[{i}] 못읽음 → +0")

        availability[date_str]["available"] = avail
        print(f" → available={avail}, total={total_seats}")

    # 7) 결과 출력 & Firestore 업로드
    for d, v in availability.items():
        print(f"{d} → {v}")
    db.collection("realtime_availability") \
      .document(camp_name) \
      .set(availability, merge=True)

finally:
    driver.quit()
