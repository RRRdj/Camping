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
cred = credentials.Certificate("camping-2f65b-firebase-adminsdk-fbsvc-9bea14a2ff.json")
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

campground_info = {
    '계룡산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[2]/a',
        'campgrounds': {
            '계룡산 갑사자동차야영장': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[2]/div/ul/li[1]/a',
            '계룡산동학사자동차야영장': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[2]/div/ul/li[2]/a'
        }
    },
    '내장산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[3]/a',
        'campgrounds': {
            '백양사 가인야영장': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[3]/div/ul/li[1]/a',
            '내장산국립공원 내장야영장': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[3]/div/ul/li[2]/a',
            '내장호야영장': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[3]/div/ul/li[3]/a'
        }
    },
    '다도해해상': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[4]/a',
        'campgrounds': {
            '다도해해상국립공원 구계등야영장': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[4]/div/ul/li[1]/a',
            '염포야영장': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[4]/div/ul/li[2]/a',
            '팔영산야영장': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[4]/div/ul/li[3]/a'
        }
    },
    '덕유산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[1]/a',
        'campgrounds': {
            '덕유대 자동차야영장': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[1]/div/ul/li[1]/a'
        }
    },
    '무등산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[2]/a',
        'campgrounds': {
            '도원야영장': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[2]/div/ul/li/a'
        }
    },
    '변산반도': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[3]/a',
        'campgrounds': {
            '변산반도국립공원 고사포 야영장': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[3]/div/ul/li[1]/a'
        }
    },
    '북한산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[4]/a',
        'campgrounds': {
            '북한산 사기막야영장': '//*[@id="container"]/div[2]/div[1]/ul[2]/li[4]/div/ul/li/a'
        }
    },
    '설악산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[1]/a',
        'campgrounds': {
            '설악산국립공원 설악동자동차야영장': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[1]/div/ul/li/a'
        }
    },
    '소백산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[2]/a',
        'campgrounds': {
            '소백산국립공원 남천야영장': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[2]/div/ul/li[1]/a',
            '소백산삼가야영장': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[2]/div/ul/li[2]/a'
        }
    },
    '오대산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[3]/a',
        'campgrounds': {
            '소금강산': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[3]/div/ul/li/a'
        }
    },
    '월악산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/a',
        'campgrounds': {
            '월악산국립공원 닷돈재 자동차야영장': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/div/ul/li[1]/a',
            '월악산국립공원 닷돈재 자동차야영장': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/div/ul/li[2]/a',
            '월악산국립공원 덕주야영장': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/div/ul/li[3]/a',
            '월악산국립공원 송계자동차 야영장': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/div/ul/li[4]/a',
            '월악산국립공원 용하야영장': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/div/ul/li[5]/a',
            '하선암 카라반 야영장': '//*[@id="container"]/div[2]/div[1]/ul[3]/li[4]/div/ul/li[6]/a'
        }
    },
    '월출산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[1]/a',
        'campgrounds': {
            '월출산국립공원 천황야영장': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[1]/div/ul/li/a'
        }
    },
    '주왕산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[2]/a',
        'campgrounds': {
            '주왕산국립공원 상의자동차 야영장': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[2]/div/ul/li/a'
        }
    },
    '지리산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/a',
        'campgrounds': {
            '내원야영장': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[1]/a',
            '달궁자동차 야영장': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[2]/a',
            '덕동자동차야영장': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[4]/a',
            '백무동야영장': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[5]/a',
            '뱀사골 힐링야영장': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[6]/a',
            '소막골야영장': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[8]/a',
            '학천야영장': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[3]/div/ul/li[9]/a'
        }
    },
    '치악산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[4]/a',
        'campgrounds': {
            '구룡자동차야영장(치악산국립공원)': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[4]/div/ul/li[1]/a',
            '금대자동차야영장': '//*[@id="container"]/div[2]/div[1]/ul[4]/li[4]/div/ul/li[2]/a'
        }
    },
    '태백산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[1]/a',
        'campgrounds': {
            '태백산국립공원 소도야영장': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[1]/div/ul/li/a'
        }
    },
    '태안해안': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[2]/a',
        'campgrounds': {
            '몽산포 자동차 야영장': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[2]/div/ul/li[1]/a',
            '학암포 오토 캠핑장': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[2]/div/ul/li[2]/a'
        }
    },
    '팔공산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[3]/a',
        'campgrounds': {
            '팔공산국립공원 갓바위야영장': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[3]/div/ul/li[1]/a',
            '팔공산국립공원 도학 야영장': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[3]/div/ul/li[2]/a'
        }
    },
    '한려해상': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[4]/a',
        'campgrounds': {
            '덕신야영장': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[4]/div/ul/li[1]/a',
            '학동자동차 야영장': '//*[@id="container"]/div[2]/div[1]/ul[5]/li[4]/div/ul/li[2]/a'
        }
    },
    '가야산': {
        'xpath': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[1]/a',
        'campgrounds': {
            '가야산국립공원 백운동야영장': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[1]/div/ul/li[1]/a',
            '삼정야영장': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[1]/div/ul/li[2]/a',
            '치인야영장': '//*[@id="container"]/div[2]/div[1]/ul[1]/li[1]/div/ul/li[3]/a'
        }
    }
}



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
        for i in range(1, 15):
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