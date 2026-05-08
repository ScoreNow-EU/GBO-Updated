import {onRequest} from "firebase-functions/v2/https";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {solveAssignment} from "./solver";

// Re-export YouTube live-broadcast + Stories functions
export {
  youtubeOAuthCallback,
  createYoutubeBroadcast,
  getYoutubeAuthUrl,
  initiateYoutubeUpload,
  finalizeStory,
  processStoryUpload,
} from "./youtube";

// Initialize Firebase Admin SDK (once, at module level)
if (admin.apps.length === 0) {
  admin.initializeApp();
}

/**
 * HTTP Cloud Function: solveAssignment
 *
 * Accepts a JSON payload with games, officials, constraints, and compatibilities.
 * Returns an optimal assignment of referees and Kampfgericht members to games,
 * maximizing the minimum break time between consecutive assignments per official.
 *
 * Input:
 *   { games, officials, constraints, compatibilities }
 *
 * Output:
 *   { assignments, breakTimes, isOptimal, warnings }
 */
export const solveGameAssignment = onRequest(
  {cors: true, memory: "512MiB", timeoutSeconds: 120},
  async (req, res) => {
    // Only allow POST
    if (req.method !== "POST") {
      res.status(405).json({error: "Method not allowed"});
      return;
    }

    try {
      const {games, officials, constraints, compatibilities} = req.body;

      if (!games || !Array.isArray(games) || games.length === 0) {
        res.status(400).json({error: "No games provided"});
        return;
      }

      if (!officials || !Array.isArray(officials) || officials.length === 0) {
        res.status(400).json({error: "No officials provided"});
        return;
      }

      const result = solveAssignment(
        games,
        officials,
        constraints || [],
        compatibilities || []
      );

      res.status(200).json(result);
    } catch (error: unknown) {
      const message =
        error instanceof Error ? error.message : "Unknown error occurred";
      console.error("Solver error:", error);
      res.status(500).json({error: message});
    }
  }
);

/**
 * Callable Cloud Function: deleteAuthUser
 *
 * Deletes a Firebase Auth user by UID using the Admin SDK.
 * Must be called by an authenticated user (e.g. admin).
 *
 * Input:  { uid: string }
 * Output: { success: true }
 */
export const deleteAuthUser = onCall(
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Must be authenticated to delete users."
      );
    }

    const uid = request.data.uid;
    if (!uid || typeof uid !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "uid must be a non-empty string."
      );
    }

    try {
      await admin.auth().deleteUser(uid);
      return {success: true};
    } catch (error: unknown) {
      const message =
        error instanceof Error ? error.message : "Unknown error occurred";
      console.error("deleteAuthUser error:", error);
      throw new HttpsError(
        "internal",
        `Failed to delete Firebase Auth user: ${message}`
      );
    }
  }
);

// ── Notification Triggers ─────────────────────────────────────────

/**
 * When a game result is updated (score change or game completed),
 * send FCM notification to tournament topic subscribers.
 */
export const onGameResultUpdated = onDocumentUpdated(
  "tournaments/{tournamentId}/games/{gameId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const tournamentId = event.params.tournamentId;
    const topic = `tournament_${tournamentId}`;

    // Game completed
    if (before.status !== "GameStatus.completed" &&
        after.status === "GameStatus.completed") {
      const teamA = after.teamAName || "Team A";
      const teamB = after.teamBName || "Team B";
      const scoreA = after.result?.teamAScore ?? 0;
      const scoreB = after.result?.teamBScore ?? 0;

      await admin.messaging().send({
        topic,
        notification: {
          title: "Ergebnis: " + teamA + " vs " + teamB,
          body: `Endstand: ${scoreA}:${scoreB}`,
        },
        data: {
          type: "game_result",
          tournamentId,
          gameId: event.params.gameId,
        },
      });
      return;
    }

    // Score update during live game
    if (after.status === "GameStatus.inProgress") {
      const resultBefore = before.result;
      const resultAfter = after.result;

      if (resultAfter &&
          (resultAfter.teamAScore !== resultBefore?.teamAScore ||
           resultAfter.teamBScore !== resultBefore?.teamBScore)) {
        const teamA = after.teamAName || "Team A";
        const teamB = after.teamBName || "Team B";

        await admin.messaging().send({
          topic,
          data: {
            type: "score_update",
            tournamentId,
            gameId: event.params.gameId,
            scoreA: String(resultAfter.teamAScore),
            scoreB: String(resultAfter.teamBScore),
            teamAName: teamA,
            teamBName: teamB,
          },
        });
      }
    }
  }
);

/**
 * When a protest is created, notify tournament subscribers.
 */
export const onProtestCreated = onDocumentCreated(
  "protests/{protestId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const tournamentId = data.tournamentId;
    if (!tournamentId) return;

    const topic = `tournament_${tournamentId}`;
    await admin.messaging().send({
      topic,
      notification: {
        title: "Protest eingereicht",
        body: data.reason
          ? `Protest: ${(data.reason as string).substring(0, 100)}`
          : "Ein neuer Protest wurde eingereicht.",
      },
      data: {
        type: "protest_filed",
        tournamentId,
        protestId: event.params.protestId,
      },
    });
  }
);
