import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { google } from "googleapis";

admin.initializeApp();

export const backupToSheets = functions.https.onCall(async (data, context) => {
    // 1. Auth check
    if (!context.auth || context.auth.token.role !== "admin") {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Only admins can trigger backups."
        );
    }

    const teamId = data.teamId;
    const sheetId = data.sheetId; // e.g., the ID of the target spreadsheet

    // 2. Fetch data from Firestore
    const snapshot = await admin.firestore()
        .collection("todos")
        .where("teamId", "==", teamId)
        .orderBy("createdAt", "desc")
        .get();

    const todos = snapshot.docs.map(doc => doc.data());

    // 3. Setup Google Sheets API
    const auth = new google.auth.GoogleAuth({
        scopes: ["https://www.googleapis.com/auth/spreadsheets"],
    });
    const authClient = await auth.getClient();
    const sheets = google.sheets({ version: "v4", auth: authClient as any });

    // 4. Transform data for Sheets
    const values = [
        ["Created At", "Content", "Priority", "Secret", "Completed"],
        ...todos.map(t => [
            t.createdAt?.toDate().toISOString() || "",
            t.content,
            t.priority,
            t.isSecret,
            t.isCompleted
        ])
    ];

    // 5. Update Google Sheet
    await sheets.spreadsheets.values.update({
        spreadsheetId: sheetId,
        range: "Sheet1!A1",
        valueInputOption: "RAW",
        requestBody: { values },
    });

    return { success: true, count: todos.length };
});
