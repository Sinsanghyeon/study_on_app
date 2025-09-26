스터디온 (StudyOn) 앱 개발 가이드
이 문서는 스터디온 앱을 로컬 환경에서 설정하고 실행하는 데 필요한 모든 절차를 안내합니다.

⚠️ 프로젝트 구조 안내
본 프로젝트의 코드는 lib/models 폴더 내 파일들과 동일한 구조를 유지해야 합니다. 모든 데이터 모델과 핵심 로직이 해당 구조에 의존하고 있으므로, 파일 구조를 임의로 변경할 경우 앱이 정상적으로 작동하지 않을 수 있습니다.

🔥 Firestore 데이터베이스 필수 설정
경고: 아래 설정을 정확히 따르지 않으면 앱이 실행되지 않거나 오류가 발생합니다.

이 앱은 Cloud Firestore에 특정 데이터 구조가 미리 설정되어 있어야 정상적으로 작동합니다. 아래 설명을 참고하여 Firestore 데이터베이스를 동일하게 구성해야 합니다.

1. 사용자 인증 (Authentication)
Firebase Console의 Authentication 메뉴 → Sign-in method 탭으로 이동합니다.

로그인 제공업체 목록에서 **'이메일/비밀번호'**를 선택하고 활성화(Enable) 합니다.

2. 필터 옵션 (filter_options)
스터디 탐색 페이지의 필터 기능을 위해 아래 문서를 직접 생성해야 합니다.

경로: app_config 컬렉션 → filter_options 문서

필드:

categoryMap (타입: map): 스터디의 주 카테고리와 하위 카테고리를 계층적으로 정의합니다.

<details>
<summary><b>🗂️ categoryMap에 입력할 전체 맵 값 보기 (클릭하여 펼치기)</b></summary>

JSON

{
    "외국어": {
        "말하기 시험": [ "OPIC (오픽)", "TOEIC Speaking (토익스피킹)" ],
        "어학 시험": [ "TOEIC (토익)", "TOEFL (토플)", "JLPT (일본어능력시험)", "HSK (한어수평고시)" ],
        "회화": [ "영어 회화", "일본어 회화", "중국어 회화" ]
    },
    "자격증": {
        "IT・SW": [ "정보처리기사", "SQLD", "ADSP (데이터분석 준전문가)", "리눅스마스터", "네트워크관리사 2급" ],
        "국어・역사": [ "한국사능력검정시험", "KBS한국어능력시험", "실용 글쓰기" ],
        "금융・회계": [ "재경관리사", "전산회계/세무", "투자자산운용사" ],
        "디자인・영상": [ "GTQ (그래픽기술자격)", "컴퓨터그래픽스운용기능사" ],
        "무역・물류": [ "국제무역사 1급", "무역영어 1급", "물류관리사", "유통관리사 2급" ],
        "사무・OA": [ "컴퓨터활용능력 1/2급", "MOS Master", "워드프로세서" ],
        "엔지니어링 (기사)": [ "일반기계기사", "전기기사", "산업안전기사", "건축기사", "토목기사" ]
    },
    "취업/이직": {
        "면접 준비": [ "기술 면접", "인성 면접", "그룹 토론", "PT 토론" ],
        "서류 준비": [ "자기소개서", "포트폴리오", "이력서" ]
    }
}
</details>

locationMap (타입: map): 필터에서 사용할 시/도 및 시/군/구 목록을 정의합니다.

<details>
<summary><b>🗺️ locationMap에 입력할 전체 지역 목록 보기 (클릭하여 펼치기)</b></summary>

JSON

{
    "강원": ["강원 전체", "강릉시", "고성군", "동해시", "삼척시", "속초시", "양구군", "양양군", "영월군", "원주시", "인제군", "정선군", "철원군", "춘천시", "태백시", "평창군", "화천군", "횡성군", "홍천군"],
    "경기": ["경기 전체", "가평군", "고양시 덕양구", "고양시 일산동구", "고양시 일산서구", "과천시", "광명시", "광주시", "구리시", "군포시", "김포시", "남양주시", "동두천시", "부천시 소사구", "부천시 오정구", "부천시 원미구", "성남시 분당구", "성남시 수정구", "성남시 중원구", "수원시 권선구", "수원시 영통구", "수원시 장안구", "수원시 팔달구", "시흥시", "안산시 단원구", "안산시 상록구", "안성시", "안양시 동안구", "안양시 만안구", "양주시", "양평군", "여주시", "연천군", "오산시", "용인시 기흥구", "용인시 수지구", "용인시 처인구", "의왕시", "의정부시", "이천시", "파주시", "평택시", "포천시", "하남시", "화성시"],
    "경남": ["경남 전체", "거제시", "거창군", "고성군", "김해시", "남해군", "밀양시", "사천시", "산청군", "양산시", "의령군", "진주시", "창녕군", "창원시", "통영시", "하동군", "함안군", "함양군", "합천군"],
    "경북": ["경북 전체", "경산시", "경주시", "고령군", "구미시", "군위군", "김천시", "문경시", "봉화군", "상주시", "성주군", "안동시", "영덕군", "영양군", "영주시", "영천시", "예천군", "울릉군", "울진군", "의성군", "청도군", "청송군", "칠곡군", "포항시 남구", "포항시 북구"],
    "광주": ["광산구", "남구", "동구", "북구", "서구"],
    "대구": ["대구 전체", "군위군", "남구", "달서구", "달성군", "동구", "북구", "서구", "수성구", "중구"],
    "대전": ["대전 전체", "대덕구", "동구", "서구", "유성구", "중구"],
    "부산": ["강서구", "금정구", "기장군", "남구", "동구", "동래구", "부산진구", "북구", "사상구", "사하구", "서구", "수영구", "연제구", "영도구", "중구", "해운대구"],
    "서울": ["서울 전체", "강남구", "강동구", "강북구", "강서구", "관악구", "광진구", "구로구", "금천구", "노원구", "도봉구", "동대문구", "동작구", "마포구", "서대문구", "서초구", "성동구", "성북구", "송파구", "양천구", "영등포구", "용산구", "은평구", "종로구", "중구", "중랑구"],
    "세종": ["세종 전체", "세종"],
    "울산": ["남구", "동구", "북구", "울주군", "중구"],
    "인천": ["인천 전체", "강화군", "계양구", "남동구", "동구", "미추홀구", "부평구", "서구", "연수구", "옹진군", "중구"],
    "전남": ["전남 전체", "강진군", "고흥군", "곡성군", "광양시", "구례군", "나주시", "담양군", "목포시", "무안군", "보성군", "순천시", "신안군", "여수시", "영광군", "영암군", "완도군", "장성군", "장흥군", "진도군", "함평군", "해남군", "화순군"],
    "전북": ["전북 전체", "고창군", "군산시", "김제시", "남원시", "무주군", "부안군", "순창군", "완주군", "익산시", "임실군", "장수군", "전주시 덕진구", "전주시 완산구", "정읍시", "진안군"],
    "제주": ["제주 전체", "서귀포시", "제주시"],
    "충남": ["충남 전체", "계룡시", "공주시", "금산군", "논산시", "당진시", "보령시", "부여군", "서산시", "서천군", "아산시", "예산군", "천안시 동남구", "천안시 서북구", "청양군", "태안군", "홍성군"],
    "충북": ["충북 전체", "괴산군", "단양군", "보은군", "영동군", "옥천군", "음성군", "제천시", "증평군", "진천군", "청주시 상당구", "청주시 서원구", "청주시 청원구", "청주시 흥덕구", "충주시"]
}
</details>

🗺️ 스터디 상세정보 구글 맵 설정
1단계: Maps_flutter 패키지 추가
pubspec.yaml 파일의 dependencies: 섹션에 아래 라인을 추가합니다.

YAML

dependencies:
  google_maps_flutter: ^2.6.1
터미널에서 flutter pub get 명령어를 실행합니다.

2단계: Google Maps API 키 발급 및 설정
Google Cloud Console에서 **"Maps SDK for Android"**와 **"Maps SDK for iOS"**를 활성화하고 API 키를 발급받습니다.

Android 설정: android/app/src/main/AndroidManifest.xml 파일의 <application> 태그 안에 아래 코드를 추가하고 YOUR_API_KEY를 교체합니다.

XML

<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="YOUR_API_KEY"/>
iOS 설정: ios/Runner/AppDelegate.swift 파일에 아래 코드를 추가하고 YOUR_API_KEY를 교체합니다.

Swift

import GoogleMaps

GMSServices.provideAPIKey("YOUR_API_KEY")
3단계: study_detail_page.dart 코드 수정
lib/models/3_category/study_detail_page.dart 파일의 내용을 아래 코드로 교체합니다.

<details>
<summary><b>👨‍💻 study_detail_page.dart 전체 코드 보기 (클릭하여 펼치기)</b></summary>

Dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class StudyDetailPage extends StatefulWidget {
  final String studyId;
  final Map<String, dynamic> studyData;
  const StudyDetailPage({super.key, required this.studyId, required this.studyData});

  @override
  State<StudyDetailPage> createState() => _StudyDetailPageState();
}

class _StudyDetailPageState extends State<StudyDetailPage> {
  GoogleMapController? _mapController; 
  final Set<Marker> _markers = {}; 
  LatLng? _studyLocation; 

  @override
  void initState() {
    super.initState();
    if (widget.studyData['type'] == '오프라인') {
      _loadMapData();
    }
  }

  Future<void> _loadMapData() async {
    String locationString = widget.studyData['location'] ?? '';
    if (locationString.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(locationString);
      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          _studyLocation = LatLng(location.latitude, location.longitude);
          final marker = Marker(
            markerId: MarkerId(widget.studyId),
            position: _studyLocation!,
            infoWindow: InfoWindow(title: widget.studyData['title']),
          );
          _markers.add(marker);
        });
      }
    } catch (e) {
      print("좌표 변환 실패: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('스터디 장소의 좌표를 찾을 수 없습니다.'))
        );
      }
    }
  }

  // ... (기타 함수들은 생략) ...

  @override
  Widget build(BuildContext context) {
    final String title = widget.studyData['title'] ?? '제목 없음';
    // ... (기타 변수 선언)

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... (기존 UI 위젯들) ...
              
              if (widget.studyData['type'] == '오프라인' && _studyLocation != null) ...[
                const SizedBox(height: 32),
                Text('📍 스터디 장소', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _studyLocation!,
                        zoom: 15,
                      ),
                      markers: _markers,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    ),
                  ),
                ),
              ],
              
              // ... (기존 UI 위젯들) ...
            ],
          ),
        ),
      ),
      // ... (기존 bottomNavigationBar) ...
    );
  }
}
</details>

🤖 AI 회의록 요약 기능 설정 (Python)
1단계: 사전 준비
Firebase 프로젝트 생성 및 Blaze 요금제 업그레이드

Firestore 데이터베이스 생성

Gemini API 키 발급: Google AI Studio에서 API 키를 발급받습니다.

2단계: Firebase Functions 환경 설정
기존 설정 삭제: 프로젝트 루트에 functions, firebase.json, .firebaserc가 있다면 모두 삭제합니다.

프로젝트 초기화: 프로젝트 루트에서 터미널을 열고 아래 명령어를 실행합니다.

Bash

firebase init functions
설정 진행: Use an existing project → 새 Firebase 프로젝트 선택 → Python → Y 순서로 선택합니다.

3단계: Python 코드 및 라이브러리 설정
functions/requirements.txt 파일 수정:

Plaintext

firebase-functions==0.2.0
firebase-admin==6.5.0
google-generativeai==0.5.0
functions/main.py 파일 수정:

<details>
<summary><b>🐍 main.py 전체 코드 보기 (클릭하여 펼치기)</b></summary>

Python

import os
from firebase_admin import initialize_app, firestore
from firebase_functions import https_fn
import google.generativeai as genai

initialize_app()

gemini_api_key = os.environ.get("GEMINI_KEY")
if gemini_api_key:
    genai.configure(api_key=gemini_api_key)
else:
    print("경고: GEMINI_KEY 환경 변수가 설정되지 않았습니다.")

@https_fn.on_call(region="asia-northeast3")
def summarizeChat(req: https_fn.CallableRequest) -> https_fn.Response:
    """스터디 채팅 내용을 요약하여 회의록을 생성합니다."""

    if not gemini_api_key:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="Gemini API 키가 서버에 설정되지 않았습니다.")
    if req.auth is None:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.UNAUTHENTICATED, message="인증된 사용자만 이 기능을 사용할 수 있습니다.")

    study_group_id = req.data.get("studyGroupId")
    if not study_group_id:
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT, message="스터디 그룹 ID가 필요합니다.")

    db = firestore.client()
    messages_ref = db.collection("chats").document(study_group_id).collection("messages").order_by("timestamp").stream()

    chat_history = ""
    for msg in messages_ref:
        msg_data = msg.to_dict()
        sender = msg_data.get("senderNickname", "익명")
        message = msg_data.get("message", "")
        chat_history += f"[{sender}]: {message}\n"

    if not chat_history.strip():
        return "요약할 채팅 내용이 없습니다."

    model = genai.GenerativeModel('gemini-pro')
    prompt = f"""
        다음은 스터디 그룹의 채팅 대화 내용이야. 이 대화 내용을 바탕으로 아래 형식에 맞춰 회의록을 생성해 줘.

        [대화 내용]
        {chat_history}

        [회의록 형식]
        ### 회의 주제
        - 이 대화의 핵심 주제를 한 문장으로 요약해 줘.
        ### 주요 논의 내용
        - 논의된 주요 내용을 항목별로 정리해 줘.
        ### 결정 사항
        - 명확하게 결정된 내용들을 정리해 줘.
        ### 할 일 (Action Items)
        - 특정 사용자에게 할당된 작업이나 다음 스터디까지 해야 할 일을 "@사용자" 형식으로 명시해서 정리해 줘.
    """

    try:
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        print(f"Gemini API 호출 중 오류 발생: {e}")
        raise https_fn.HttpsError(code=https_fn.FunctionsErrorCode.INTERNAL, message="AI 모델을 호출하는 중 오류가 발생했습니다.")
</details>

라이브러리 수동 설치:

Bash

# 1. functions 폴더로 이동
cd functions
# 2. 가상 환경 활성화
source venv/Scripts/activate
# 3. 라이브러리 설치
pip install -r requirements.txt
# 4. 프로젝트 루트로 복귀
cd ..
4단계: API 키 설정 및 최종 배포
API 키 설정: 프로젝트 루트에서 아래 명령어를 실행합니다. (YOUR_GEMINI_API_KEY는 실제 키로 교체)

Bash

firebase functions:config:set gemini.key="YOUR_GEMINI_API_KEY"
배포:

Bash

firebase deploy --only functions
