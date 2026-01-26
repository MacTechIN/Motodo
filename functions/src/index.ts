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

// Use v1 for document triggers for simpler path matching in this snippet
import * as firestore from "firebase-functions/v1/firestore";

/**
 * Aggregates team stats from shards on write.
 * For 1,000+ users, this handles the 1-write-per-second limit.
 */
export const aggregateTeamStats = firestore
    .document("teams/{teamId}/counters/{shardId}")
    .onWrite(async (change: any, context: any) => {
        const teamId = context.params.teamId;
        const countersRef = admin.firestore().collection("teams").doc(teamId).collection("counters");

        const shardsSnapshot = await countersRef.get();
        let totalCompleted = 0;
        let totalCount = 0;

        shardsSnapshot.forEach(doc => {
            const data = doc.data();
            totalCompleted += data.completed || 0;
            totalCount += data.total || 0;
        });

        await admin.firestore().collection("teams").doc(teamId).set({
            stats: {
                totalCompleted,
                totalCount,
                completionRate: totalCount > 0 ? (totalCompleted / totalCount) : 0,
                lastUpdated: admin.firestore.FieldValue.serverTimestamp()
            }
        }, { merge: true });
    });
