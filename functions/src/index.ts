import {onRequest} from "firebase-functions/v2/https";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {solveAssignment} from "./solver";

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
