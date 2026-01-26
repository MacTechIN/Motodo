# Motodo System Verification Report

**Date**: 2026-01-26
**Version**: V2.2
**Status**: ⚠️ Passed with Critical Action Items

본 리포트는 Motodo 프로젝트의 UI, Data, Communication 레이어에 대한 검증 결과와 발견된 이슈, 그리고 해결 방안을 기술합니다.

## 1. 🔍 Verification Summary

| Component | Status | Notes |
| :--- | :--- | :--- |
| **UI Layer** | ✅ Pass | Reference Design과 일치, 반응형 동작 확인. |
| **Data Layer** | ✅ Pass | Firestore 스키마 준수, 오프라인 모드 활성화됨. |
| **Logic/Comm** | ⚠️ **Warning** | Cloud Function 권한 검증 로직에서 불일치 발견. |

---

## 2. 🚨 Critical Issues & Action Plan

### [CRITICAL] Cloud Function Admin Permission Denied
- **Issue**:
  - `functions/src/index.ts`의 관리자 기능(`backupToSheets`, `exportTeamToCSV`, `getAdminDashboardMetrics`)은 `request.auth.token.role === 'admin'`을 통해 권한을 검사합니다.
  - 그러나 현재 `AuthProvider.createTeam` 함수는 Firestore의 `users/{uid}` 문서에만 `role: 'admin'`을 기록하며, **Firebase Auth Token의 Custom Claim(claims.role)을 업데이트하지 않습니다.**
  - 결과적으로, 관리자가 해당 API를 호출하면 **"permission-denied"** 에러가 발생합니다.

- **Root Cause**:
  - Firestore 문서의 변경 사항이 Firebase Auth Token에 자동으로 반영되지 않음.

- **Recommended Fix (Post-Release Patch)**:
  1.  **Option A (Backend Force)**: 새로운 Cloud Function 트리거(`onDocumentUpdated`)를 작성하여, Firestore `users/{uid}`의 `role`이 변경될 때 `admin.auth().setCustomUserClaims(uid, { role })`를 실행하도록 구현해야 합니다.
  2.  **Option B (Short-term Patch)**: Cloud Function의 권한 검사 로직을 `request.auth.token.role` 대신, 함수 내부에서 `admin.firestore().collection('users').doc(uid).get()`를 통해 Firestore 문서를 직접 조회하는 방식으로 변경해야 합니다. (비용 증가하지만 즉시 해결 가능)

---

## 3. ✅ Verification Details

### A. UI/UX Verification
- **Header**: `intl` 기반의 시간대별 인사말 로직(Morning/Afternoon/Evening)이 정상적으로 구현되었습니다.
- **Card Layout**: "My Focus" 카드의 상/하단 분리 레이아웃이 Reference Image와 일치합니다.
- **Grid**: `childAspectRatio: 1.4` 설정은 일반적인 모바일 화면에서 적절성 확인되었으나, 태블릿 등에서는 테스트가 권장됩니다.

### B. Data Integrity (API Specs)
- **Time Sync**: `TodoProvider`에서 `createdAt`과 `completedAt`을 `FieldValue.serverTimestamp()`로 처리하고 있어, 클라이언트 시간 조작에 영향을 받지 않습니다.
- **Offline Persistence**: `main.dart`에 `persistenceEnabled: true`가 선언되어 있어, 네트워크 단절 시에도 쓰기 작업이 큐에 쌓이고 재연결 시 동기화됩니다.

### C. Export Logic
- **CSV Formatting**: `duration` 계산 로직(`diffMs / 3,600,000`)과 `priority` 텍스트 변환 맵핑이 정상적으로 구현되었습니다.
- **Privacy**: `isSecret` 플래그에 따른 내용 마스킹("🔒 개인 업무") 로직이 안전하게 적용되었습니다.

## 4. Conclusion
Motodo V2.2는 기능적으로 완성도가 높으나, **관리자 권한 인증(Auth Claims)** 부분에서 배포 후 통합 테스트 시 이슈가 발생할 수 있습니다. 상기된 "Recommended Fix"를 차기 패치(V2.2.1)에 포함시킬 것을 강력히 권장합니다.
