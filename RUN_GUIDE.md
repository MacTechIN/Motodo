# How to Run Motodo

## Prerequisites
- Flutter SDK installed
- Firebase CLI installed
- Node.js installed

## 1. Setup Backend (Firebase Functions)
The functions are written in TypeScript.

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

## 2. Run Frontend (Flutter App)
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## 3. Verify Admin Features
- Login to the app.
- Create a new team (this promotes you to Admin).
- Go to Dashboard -> Admin Panel.
- Test "Export CSV" or "Backup".
