# API / Firestore Interface Reference

본 문서는 Motodo 프로젝트의 백엔드(Firebase)와 프론트엔드 간의 데이터 통신 규격을 정의합니다.

## A. User & Team Management

### 1. 회원가입 / 프로필 (Join)
- **Method**: `setDoc` (Firestore)
- **Collection**: `users`
- **Document ID**: `uid` (Firebase Auth UID)
- **Data Structure**:
  ```json
  {
    "email": "user@example.com",
    "displayName": "User Name",
    "lastLoginAt": "Timestamp (Server)",
    "teamId": "nullable",
    "role": "member" // or "admin"
  }
  ```

### 2. 팀 생성 (Create Team)
- **Method**: `addDoc`
- **Collection**: `teams`
- **Data Structure**:
  ```json
  {
    "name": "Team Name",
    "adminUid": "uid",
    "createdAt": "Timestamp",
    "plan": "free", // or "pro"
    "stats": { "totalCount": 0, "totalCompleted": 0 }
  }
  ```

### 3. 팀원 활동 조회 (Team Pulse)
- **Method**: `query` (listen/snapshots)
- **Query**:
  - `collection('todos')`
  - `.where('teamId', '==', teamId)`
  - `.where('isSecret', '==', false)` (공개 업무만)

---

## B. Todo CRUD (Core)

### 1. 할 일 생성 (Create Todo)
- **Method**: `addDoc`
- **Collection**: `todos`
- **Data Structure**:
  ```json
  {
    "content": "String",
    "priority": 1-5 (Int),
    "isSecret": Boolean,
    "isCompleted": false,
    "createdBy": "uid",
    "teamId": "teamId",
    "createdAt": "Timestamp"
  }
  ```

### 2. 상태 업데이트 (Update Status)
- **Method**: `updateDoc`
- **Fields**:
  - `isCompleted`: Boolean
  - `completedAt`: `FieldValue.serverTimestamp()` (서버 시간 기록)

### 3. 필터링 조회 (Filtering)
- **Method**: `query`
- **Indices**: `teamId`, `createdBy`, `priority`, `completedAt`
