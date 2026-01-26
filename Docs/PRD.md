# Motodo Project (모두의 해야 할 일) - Strategic B2B PRD

## 1. 프로젝트 개요
- **비전**: 팀 간의 실시간 의사소통과 협업을 극대화하는 B2B SaaS 협업 플랫폼.
- **핵심 목표**: 1,000명 이상의 동시 접속 환경에서도 지연 없는 실시간 동기화 제공.
- **크로스 플랫폼 전략**: **Flutter**를 통한 단일 코드베이스 (Web, Desktop, Mobile) 대응.

## 2. 비즈니스 모델 (BM)
- **Freemium SaaS (부분 유료화)**
    - **Free Tier**: 5인 이하 소규모 팀. 기본 Todo 및 실시간 공유.
    - **Pro Tier**: 인원 무제한, Excel/CSV 백업, 고급 통계 대시보드 제공.

## 3. 추천 기술 스택 (High Performance & Scalability)
- **Frontend**: **Flutter (Dart)**
    - 장점: 고성능 렌더링, Web/Desktop/Mobile 단일 코드베이스 지원.
- **Backend**: **NestJS (Node.js/TypeScript)**
    - 장점: 대용량 트래픽 처리에 유리하며 유지보수성이 뛰어난 모듈형 구조.
- **Database**: **PostgreSQL**
    - 장점: 데이터 무결성(회사-팀-사용자 관계) 보장에 최적화된 RDBMS.
- **Infra & Caching**: **AWS (EC2, RDS) + Redis**
    - 장점: Redis 캐싱을 통한 실시간 세션 관리 및 1,000명 동시 접속 부하 분산.

## 4. MVP 핵심 전략 & 범위
- **핵심 가치**: "내 할 일을 적으면, 팀원이 바로 안다."
- **실시간 동기화**: Socket.io를 활용한 초저지연 상태 공유.
- **보안 필터링**: '비밀' Todo에 대한 백엔드 레벨 필터링.
- **Pastel UI**: 컬러 코딩을 통한 직관적 업무 식별.

## 5. 개발 로드맵 (Updated)
- **1단계**: NestJS & PostgreSQL 기반 백엔드 아키텍처 구축 (현재)
- **2단계**: Flutter 크로스 플랫폼 베이스 구현
- **3단계**: Redis 연동 실시간 동기화 엔진 적용
- **4단계**: Pro 기능 구현 및 부하 테스트
