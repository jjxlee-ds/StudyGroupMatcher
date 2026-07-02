# Study Group Matcher — Project Context

## 프로젝트 개요
NYU 데이터사이언스 학생 JJ Lee의 포트폴리오 프로젝트.
스터디 그룹 매칭 앱. 포트폴리오 Live Demo용으로 완성도 높이는 작업 중.

## 현재 스택
- Frontend: Flutter (Dart), frontend/lib
- Backend: FastAPI (Python), backend/app/main.py, port 8000
- DB: Supabase (PostgreSQL)

## 현재 상태
- 로컬 실행 확인 완료 (Flutter web on localhost, FastAPI on :8000)
- 로그인/회원가입 작동 확인
- 홈 화면, RECS, CHATTING, CALENDAR, PROFILE 탭 구조 존재

## 목표
1. 앱 전체 기능 둘러보며 버그/미완성 부분 파악
2. Flutter 웹 빌드 후 배포 (Vercel 또는 Netlify)
3. 포트폴리오 Live Demo로 사용 가능하게 완성도 높이기

## 로컬 실행
- Backend: cd backend && uvicorn app.main:app --reload --port 8000
- Frontend: cd frontend && flutter run -d chrome
- API URL: frontend/lib/config/api_config.dart (현재 http://localhost:8000)

## Supabase
- 프로젝트: GroupstudyMatch
- URL: https://tddbudcgoalnjnsaqtoo.supabase.co
- .env 파일: backend/.env (SUPABASE_URL, SUPABASE_KEY, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_JWT_SECRET)
