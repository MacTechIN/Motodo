# Motodo (모두의 해야 할 일)

**Motodo**는 "내가 적으면 팀원이 즉시 아는" 실시간 초투명성을 지향하는 B2B SaaS 협업 툴입니다. 1,000명 이상의 동시 접속을 수용할 수 있는 강력한 고성능 아키텍처를 기반으로 합니다.

## 🛠 Tech Stack
- **Frontend**: **Flutter** (Web, Mobile, Desktop 단일 코드베이스)
- **Backend**: **NestJS** (Modular Architecture)
- **Database**: **PostgreSQL** + **Prisma ORM**
- **Auth**: **JWT (JSON Web Token)**
- **API Docs**: **Swagger / OpenAPI**
- **Real-time**: **Socket.io** (Ready)

## 📁 Project Structure
```bash
.
├── backend/            # NestJS Backend Application
├── frontend/           # Flutter Frontend Application
├── firestore.rules     # Firestore Security Rules (Backup)
├── Docs/               # Project Planning & PRD
└── README.md           # Documentation
```

## 🚀 Getting Started

### Backend Setup
```bash
cd backend
npm install
# Configure .env with DATABASE_URL
npx prisma generate
npm run start:dev
```
- API Documents: `http://localhost:3000/api`

### Frontend Setup
```bash
cd frontend
flutter pub get
flutter run
```

## 🛡 Code Quality & Git Workflow

### Commit Messages
시맨틱 커밋 메시지 컨벤션을 따릅니다:
- `feat`: 신규 기능 추가
- `fix`: 버그 수정
- `docs`: 문서 수정
- `refactor`: 코드 리팩토링
- `test`: 테스트 코드 추가/수정

### Git Hooks (Husky)
- **commit-msg**: Commitlint를 통해 메시지 컨벤션을 자동 검사합니다.
- **pre-push**: Push 전에 백엔드 린트/테스트 및 프론트엔드 분석을 강제합니다.

---

## 🔐 Security Key Features
- **Privacy Filtering**: 상급자/팀원 리스트 조회 시 `isSecret: true`인 할 일은 DB 레벨에서 필터링되어 절대 유출되지 않습니다.
- **JWT Protection**: 모든 API는 유효한 토큰이 있어야 접근 가능합니다.
- **Admin Specifics**: 어드민 유저만 팀 전체 데이터를 CSV로 백업할 수 있는 전용 엔드포인트를 제공합니다.

---
© 2026 Motodo B2B Project

## 🛡️ Advanced Features (V1.2)
- **Sub-collections (Comments)**: Each Todo document hosts a `comments` sub-collection, optimizing bandwidth.
- **Distributed Sharding Counter**: Teams use a 5-shard counter mechanism to scale write performance for real-time statistics (e.g., team completion rate).
- **Hardened Security Rules**: Server-side validation ensures strictly enforced privacy—`isSecret` tasks are never transmitted to non-owners.
