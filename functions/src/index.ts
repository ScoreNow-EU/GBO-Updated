import * as functions from "firebase-functions";
import {solveAssignment} from "./solver";

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
export const solveGameAssignment = functions.https.onRequest(
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
