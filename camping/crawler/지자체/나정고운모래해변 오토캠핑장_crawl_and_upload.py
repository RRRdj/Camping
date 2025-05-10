from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import (
    TimeoutException,
    NoSuchElementException,
    StaleElementReferenceException
)
from webdriver_manager.chrome import ChromeDriverManager
import time
import re

import calendar

import firebase_admin
from firebase_admin import credentials, firestore

# ──────────────────────────────────────────────────────────────────────────────
# Firebase 인증 및 초기화
cred = credentials.Certificate("camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# ──────────────────────────────────────────────────────────────────────────────
# WebDriver 설정
options = webdriver.ChromeOptions()
# options.add_argument('--headless')  # 헤드리스 실행 필요 시 주석 해제
options.add_argument('--disable-dev-shm-usage')
driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=options
)

# ──────────────────────────────────────────────────────────────────────────────
# 1) 스크래핑 대상 정의
URL       = "https://camp.xticket.kr/web/main?shopEncode=08f2d6ac872d55a829cd62de5a910ff0922eeb57506d4ddbe021224fce47d006"
camp_name = "나정고운모래 해변오토캠핑장"

# 2) 연·월 (하드코딩)
YEAR, MONTH = 2025, 5

# ── 메인 페이지 열고 팝업 닫기 & 달력의 활성 날짜 수집 ──
driver.get(URL)
try:
    pop_btn = WebDriverWait(driver, 5).until(
        EC.element_to_be_clickable((By.XPATH,
            "//*[@id='notice_layer_882']/div/div/div/fieldset/ul/li/button/img"
        ))
    )
    pop_btn.click()
except TimeoutException:
    pass

time.sleep(1)  # 완전 로딩 대기

# 활성화된 날짜들의 <a> 요소에서 숫자만 골라 리스트로
date_elems = driver.find_elements(By.XPATH, "//table[@id='calendarTable']//a")
day_list = sorted(
    int(e.text) for e in date_elems
    if e.text.strip().isdigit()
)

# ──────────────────────────────────────────────────────────────────────────────
availability = {}
total_seats = 41  # 고정

for day in day_list:
    # 매번 메인 페이지로 돌아가 팝업 닫고 날짜 클릭
    driver.get(URL)
    try:
        pop_btn = WebDriverWait(driver, 5).until(
            EC.element_to_be_clickable((By.XPATH,
                "//*[@id='notice_layer_882']/div/div/div/fieldset/ul/li/button/img"
            ))
        )
        pop_btn.click()
    except TimeoutException:
        pass
    time.sleep(0.5)

    # 날짜 클릭 (재시도 포함)
    xpath_date = f"//table[@id='calendarTable']//a[text()='{day}']"
    for _ in range(3):
        try:
            elem = WebDriverWait(driver, 5).until(
                EC.presence_of_element_located((By.XPATH, xpath_date))
            )
            driver.execute_script("arguments[0].click();", elem)
            break
        except (StaleElementReferenceException, TimeoutException):
            time.sleep(0.5)
    else:
        print(f"{day}일 클릭 실패, 건너뜁니다.")
        continue

    time.sleep(1)  # 로딩 대기

    # 아이콘 개수 세기
    cnt = 0
    for i in range(1, total_seats + 1):
        elem_id = f"010100{str(i).zfill(2)}"
        try:
            img = driver.find_element(By.ID, elem_id)
            src = img.get_attribute("src") or ""
            if src.endswith("product_map_house20x20.png"):
                cnt += 1
        except NoSuchElementException:
            continue

    date_str = f"{YEAR}-{MONTH:02d}-{day:02d}"
    availability[date_str] = {
        "available": cnt,
        "total":     total_seats
    }
    print(f"{date_str} → available: {cnt}, total: {total_seats}")

# ── Firestore 업로드 & 출력 ──
for d, v in availability.items():
    print(f"{d} → {v}")

db.collection("realtime_availability") \
  .document(camp_name) \
  .set(availability, merge=True)

driver.quit()
