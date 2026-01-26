import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { google } from "googleapis";
import { Parser } from "json2csv";

admin.initializeApp();

export const backupToSheets = onCall(async (request) => {
    if (!request.auth || request.auth.token.role !== "admin") {
        throw new HttpsError("permission-denied", "Only admins can trigger backups.");
    }

    const teamId = request.data.teamId;
    const sheetId = request.data.sheetId;

    const snapshot = await admin.firestore()
        .collection("todos")
        .where("teamId", "==", teamId)
        .orderBy("createdAt", "desc")
        .get();

    const todos = snapshot.docs.map(doc => doc.data());

    const auth = new google.auth.GoogleAuth({
        scopes: ["https://www.googleapis.com/auth/spreadsheets"],
    });
    const authClient = await auth.getClient();
    const sheets = google.sheets({ version: "v4", auth: authClient as any });

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

/**
 * Admin-only CSV Export
 */
export const exportTeamToCSV = onCall(async (request) => {
    if (!request.auth || request.auth.token.role !== "admin") {
        throw new HttpsError("permission-denied", "Admin ONLY.");
    }

    const teamId = request.data.teamId;
    const snapshot = await admin.firestore().collection("todos").where("teamId", "==", teamId).get();
    const todos = snapshot.docs.map(doc => {
        const d = doc.data();
        return {
            id: doc.id,
            content: d.content,
            priority: d.priority,
            isCompleted: d.isCompleted,
            createdBy: d.createdBy,
            createdAt: d.createdAt?.toDate().toISOString() || ""
        };
    });

    try {
        const fields = ["id", "content", "priority", "isCompleted", "createdBy", "createdAt"];
        const parser = new Parser({ fields });
        const csv = parser.parse(todos);
        return { success: true, csv };
    } catch (err) {
        throw new HttpsError("internal", "CSV failure");
    }
});
