import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { google } from "googleapis";
import { Parser } from "json2csv";

admin.initializeApp();

export const backupToSheets = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged in.");
    }

    const db = admin.firestore();
    const userId = request.auth.uid;
    const userDoc = await db.collection("users").doc(userId).get();

    if (userDoc.data()?.role !== "admin") {
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

    // Save lastBackupAt for "Pending Data" metric
    await admin.firestore().collection("teams").doc(teamId).set({
        lastBackupAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return { success: true, count: todos.length };
});

/**
 * Admin Dashboard Metrics Aggregation
 */
export const getAdminDashboardMetrics = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged in.");
    }

    const db = admin.firestore();
    const userId = request.auth.uid;
    // Check role from DB to avoid stale custom claims
    const userDoc = await db.collection("users").doc(userId).get();
    if (userDoc.data()?.role !== "admin") {
        throw new HttpsError("permission-denied", "Admin ONLY.");
    }

    const teamId = request.data.teamId;

    // 1. Active Rate (Users logged in within 24h)
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const activeUsersSnap = await db.collection("users")
        .where("teamId", "==", teamId)
        .where("lastLoginAt", ">=", yesterday)
        .get(); // In prod use count() aggregation
    const activeCount = activeUsersSnap.size;

    // 2. Completion Rate (from Sharded Counters)
    const teamDoc = await db.collection("teams").doc(teamId).get();
    const stats = teamDoc.data()?.stats || { totalCompleted: 0, totalCount: 0 };
    const completionRate = stats.totalCount > 0
        ? Math.round((stats.totalCompleted / stats.totalCount) * 100)
        : 0;

    // 3. Priority Distribution (Priority 5 count)
    const p5Snap = await db.collection("todos")
        .where("teamId", "==", teamId)
        .where("priority", "==", 5)
        .where("isCompleted", "==", false)
        .get(); // In prod use count()
    const urgentCount = p5Snap.size;

    // 4. Backup Pending Data
    const lastBackupAt = teamDoc.data()?.lastBackupAt;
    let pendingCount = 0;
    if (lastBackupAt) {
        const pendingSnap = await db.collection("todos")
            .where("teamId", "==", teamId)
            .where("createdAt", ">", lastBackupAt)
            .get();
        pendingCount = pendingSnap.size;
    } else {
        // Never backed up? Count all.
        pendingCount = stats.totalCount;
    }

    return {
        activeUserCount: activeCount,
        completionRate: completionRate,
        urgentCount: urgentCount,
        backupPendingCount: pendingCount
    };
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
/**
 * Admin-only CSV Export
 */
export const exportTeamToCSV = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "User must be logged in.");
    }

    const db = admin.firestore();
    const userId = request.auth.uid;
    const userDoc = await db.collection("users").doc(userId).get();

    if (userDoc.data()?.role !== "admin") {
        throw new HttpsError("permission-denied", "Admin ONLY.");
    }

    const teamId = request.data.teamId;

    // 1. Fetch Todos
    const snapshot = await db.collection("todos").where("teamId", "==", teamId).get();

    // 2. Fetch Users Map for Name Resolution
    // (Optimization: In a huge app, we might store userName in Todo or fetch in batches. 
    // For MVP/SMB, fetching team users is acceptable)
    const usersSnap = await db.collection("users").where("teamId", "==", teamId).get();
    const userMap: { [uid: string]: string } = {};
    usersSnap.forEach(doc => {
        const u = doc.data();
        userMap[doc.id] = u.displayName || "Unknown User";
    });

    const todos = snapshot.docs.map(doc => {
        const d = doc.data();

        // Calculate Duration
        let durationHours = "0.00";
        const createdAt = d.createdAt?.toDate();
        const completedAt = d.completedAt?.toDate();

        if (d.isCompleted && createdAt && completedAt) {
            const diffMs = completedAt.getTime() - createdAt.getTime();
            durationHours = (diffMs / (1000 * 60 * 60)).toFixed(2);
        }

        // Priority to Text
        const priorityMap: { [key: number]: string } = {
            5: "매우 높음 (Very High)",
            4: "높음 (High)",
            3: "보통 (Medium)",
            2: "낮음 (Low)",
            1: "매우 낮음 (Very Low)"
        };
        const priorityText = priorityMap[d.priority] || "보통";

        // Privacy Masking (Strict Admin Report)
        // If secret, we show "Private Task" as requested in specs.
        const content = d.isSecret ? "🔒 개인 업무 (Private Task)" : d.content;
        const privacyStatus = d.isSecret ? "Personal" : "Public";

        return {
            userName: userMap[d.createdBy] || d.createdBy, // Name Resolution
            content: content,
            priority: priorityText, // Text Conversion
            duration: durationHours, // Duration
            privacy: privacyStatus, // Privacy Status
            createdAt: createdAt?.toISOString() || "",
            completedAt: completedAt?.toISOString() || ""
        };
    });

    try {
        const fields = ["userName", "content", "priority", "duration", "privacy", "createdAt", "completedAt"];
        const parser = new Parser({ fields });
        const csv = parser.parse(todos);
        return { success: true, csv };
    } catch (err) {
        throw new HttpsError("internal", "CSV failure");
    }
});

/**
 * Team Pulse Engine: Updates member stats on Todo changes.
 * Allows admins to monitor status without violating privacy.
 */
export const updateMemberStats = firestore
    .document("todos/{todoId}")
    .onWrite(async (change: any, context: any) => {
        // Get the document data (either before or after) to identify user and team
        const data = change.after.exists ? change.after.data() : change.before.data();
        const userId = data.createdBy;
        const teamId = data.teamId;

        if (!userId || !teamId) return;

        const db = admin.firestore();

        // Recount all active tasks for this user to ensure consistency
        // This avoids complex increment/decrement logic on privacy edge cases
        const snapshot = await db.collection("todos")
            .where("teamId", "==", teamId)
            .where("createdBy", "==", userId)
            .where("isCompleted", "==", false)
            .get();

        let activeCount = 0;
        let secretCount = 0;
        let highPriorityCount = 0;

        snapshot.forEach(doc => {
            const t = doc.data();
            activeCount++;
            if (t.isSecret) secretCount++;
            if (t.priority >= 4) highPriorityCount++;
        });

        // Update Member Stats Document
        await db.collection("teams").doc(teamId).collection("members").doc(userId).set({
            activeCount,
            secretCount,
            highPriorityCount,
            lastActivityAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
    });

/**
 * Weekly Analytics Report (Pro Feature)
 * Scheduled to run every Monday at 9:00 AM.
 * (Note: For MVP, we log the report. In prod, use Nodemailer/SendGrid)
 */
export const sendWeeklyReport = onCall(async (request) => {
    // In a real scheduled function, we wouldn't use onCall, but onSchedule.
    // implementing onCall here for easy manual testing by the user/admin.

    // 1. Scan all PRO teams
    // For MVP, just specific teamId provided or all teams
    const db = admin.firestore();
    const teamsSnap = await db.collection("teams").get();

    const reports: any[] = [];

    for (const teamDoc of teamsSnap.docs) {
        const teamData = teamDoc.data();
        if (teamData.plan !== 'pro') continue; // Only Pro teams

        const teamId = teamDoc.id;

        // 2. Aggregate Weekly Stats
        const lastWeek = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        const completedSnap = await db.collection("todos")
            .where("teamId", "==", teamId)
            .where("isCompleted", "==", true)
            .where("completedAt", ">=", lastWeek)
            .get();

        const completedCount = completedSnap.size;

        // 3. Mock Email Sending
        const report = {
            teamId,
            recipient: "admin@motodo.com", // In prod, teamData.adminEmail
            subject: `[Motodo] Weekly Analytics for ${teamData.name || 'Team'}`,
            body: `You completed ${completedCount} tasks last week! Great job.`
        };

        console.log("SENDING EMAIL:", report);
        reports.push(report);
    }

    return { success: true, reportsSent: reports.length };
});
