/**
 * Scoreboard API – Firebase Cloud Function
 *
 * Authentication: existing Firebase Auth accounts (email + password).
 * Login returns the Firebase ID token directly – no custom JWT needed.
 * Every subsequent request carries that token as a Bearer token and the
 * server verifies it with admin.auth().verifyIdToken().
 *
 * Access requires role "admin" or "scoringTablet" in users/{uid}.roles.
 *
 * ⚠️  Time is CLIENT-MANAGED. The server never calculates or increments time.
 *     The scoreboard device runs its own timer and may optionally sync
 *     (minutes / seconds / isRunning) via PUT /state for SSE display.
 *
 * Base URL: https://REGION-PROJECT.cloudfunctions.net/scoreboardApi/<path>
 *
 * Environment variable required:
 *   GBO_WEB_API_KEY  – Firebase project Web API key
 *                           (Console → Project settings → General → Web API key)
 *
 * Firestore collections:
 *   users/{uid}                 – Firebase Auth users with roles array
 *   courts                      – court / field documents
 *   tournaments/{id}/games/{id} – game documents
 *   gameStates/{gameId}         – score / period state (+ optional time sync)
 *   gameEvents/{eventId}        – game events (goals, cards, timeouts, …)
 */

// Roles that grant scoreboard access
const SCOREBOARD_ROLES = ["admin", "scoringTablet", "scoreboard"];

import {onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import type {Request, Response} from "express";

// ─── Firestore shorthand ──────────────────────────────────────────────────────

const db = () => admin.firestore();
const sv = () => admin.firestore.FieldValue.serverTimestamp();

// ─── Auth context ─────────────────────────────────────────────────────────────

interface AuthContext {
  uid: string;
  email: string;
  role: string; // "admin" | "scoreboard"
}

/**
 * Verifies a Firebase ID token from the Authorization header and checks that
 * the user has a scoreboard-eligible role in Firestore.
 */
async function resolveAuth(req: Request): Promise<AuthContext | null> {
  const header = req.headers["authorization"];
  if (typeof header !== "string" || !header.startsWith("Bearer ")) return null;
  const idToken = header.slice(7);
  try {
    const decoded = await admin.auth().verifyIdToken(idToken, /* checkRevoked */ true);
    const userDoc = await db().collection("users").doc(decoded.uid).get();
    if (!userDoc.exists) return null;
    const data = userDoc.data()!;
    if (!data.isActive) return null;
    const roles: string[] = Array.isArray(data.roles) ? data.roles : [];
    if (!roles.some((r) => SCOREBOARD_ROLES.includes(r))) return null;
    return {
      uid: decoded.uid,
      email: decoded.email ?? "",
      role: roles.includes("admin") ? "admin" : "scoreboard",
    };
  } catch {
    return null;
  }
}

/** Returns false and sends 401/403 when auth is missing or insufficient. */
function requireAuth(
  auth: AuthContext | null,
  res: Response,
  adminOnly = false
): auth is AuthContext {
  if (!auth) {
    res.status(401).json({error: "Unauthorized – valid Firebase ID token required"});
    return false;
  }
  if (adminOnly && auth.role !== "admin") {
    res.status(403).json({error: "Forbidden – admin role required"});
    return false;
  }
  return true;
}

// ─── Route handler type ───────────────────────────────────────────────────────

type Params = Record<string, string>;
type Handler = (
  req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
) => Promise<void>;

// ─── Auth handlers ────────────────────────────────────────────────────────────

/**
 * POST /login  { email, password }
 * Calls the Firebase Auth REST API and returns the Firebase ID token directly.
 * The client uses this token as a Bearer token for all subsequent requests.
 * Tokens expire after 1 hour; use the returned refreshToken to get a new one.
 */
async function handleLogin(req: Request, res: Response): Promise<void> {
  const {email, password} = req.body ?? {};
  if (!email || !password) {
    res.status(400).json({error: "email and password are required"});
    return;
  }

  const apiKey = process.env.GBO_WEB_API_KEY;
  if (!apiKey) {
    res.status(500).json({error: "Server misconfiguration: GBO_WEB_API_KEY not set"});
    return;
  }

  // Sign in via Firebase Auth REST API
  const authResp = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({email, password, returnSecureToken: true}),
    }
  );

  if (!authResp.ok) {
    const errBody = await authResp.json() as {error?: {message?: string}};
    const msg = errBody?.error?.message ?? "";
    const isCredentialError =
      msg.includes("INVALID_PASSWORD") ||
      msg.includes("EMAIL_NOT_FOUND") ||
      msg.includes("INVALID_LOGIN_CREDENTIALS") ||
      msg.includes("TOO_MANY_ATTEMPTS_TRY_LATER");
    res.status(401).json({
      error: isCredentialError ? "Invalid email or password" : "Authentication failed",
    });
    return;
  }

  const authData = await authResp.json() as {
    localId: string;
    email: string;
    idToken: string;
    refreshToken: string;
    expiresIn: string;
  };
  const uid = authData.localId;

  // Check role in Firestore
  const userDoc = await db().collection("users").doc(uid).get();
  if (!userDoc.exists) {
    res.status(403).json({error: "User not found in system"});
    return;
  }
  const userData = userDoc.data()!;
  if (!userData.isActive) {
    res.status(403).json({error: "Account is inactive"});
    return;
  }
  const roles: string[] = Array.isArray(userData.roles) ? userData.roles : [];
  if (!roles.some((r) => SCOREBOARD_ROLES.includes(r))) {
    res.status(403).json({
      error: "Insufficient permissions – admin or scoringTablet role required",
    });
    return;
  }

  await userDoc.ref.update({lastLoginAt: sv()});

  res.json({
    // The Firebase ID token IS the bearer token – pass it as Authorization: Bearer <token>
    token: authData.idToken,
    refreshToken: authData.refreshToken,
    expiresIn: parseInt(authData.expiresIn), // seconds (typically 3600)
    uid,
    email: authData.email,
    firstName: userData.firstName ?? "",
    lastName: userData.lastName ?? "",
    role: roles.includes("admin") ? "admin" : "scoreboard",
    roles,
  });
}

/**
 * POST /logout
 * Revokes all refresh tokens for the user so no new ID tokens can be issued.
 * Note: existing ID tokens remain valid until they expire (max 1 h).
 */
async function handleLogout(
  _req: Request,
  res: Response,
  auth: AuthContext | null
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  await admin.auth().revokeRefreshTokens(auth.uid);
  res.json({ok: true});
}

/** GET /me */
async function handleMe(
  _req: Request,
  res: Response,
  auth: AuthContext | null
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const doc = await db().collection("users").doc(auth.uid).get();
  if (!doc.exists) {
    res.status(404).json({error: "User not found"});
    return;
  }
  const {email, firstName, lastName, roles, isActive, defaultTournamentFilter, defaultSeason} =
    doc.data()!;
  res.json({uid: auth.uid, email, firstName, lastName, roles, isActive,
    defaultTournamentFilter, defaultSeason});
}

// ─── Courts handler ───────────────────────────────────────────────────────────

/** GET /courts – list all courts */
async function handleListCourts(
  _req: Request,
  res: Response,
  auth: AuthContext | null
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const snap = await db().collection("courts").orderBy("name").get();
  res.json(snap.docs.map((d) => ({id: d.id, ...d.data()})));
}

// ─── Game handlers ────────────────────────────────────────────────────────────

/**
 * GET /games
 * All query params are optional.
 * Without filters, returns games from all tournaments (collectionGroup).
 * Filters: tournamentId?, courtId?, status?, date? (ISO date string)
 */
async function handleListGames(
  req: Request,
  res: Response,
  auth: AuthContext | null
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const {tournamentId, courtId, status, date} = req.query as Record<string, string>;

  let query: admin.firestore.Query;

  if (tournamentId) {
    query = db().collection(`tournaments/${tournamentId}/games`);
  } else {
    // collectionGroup covers all tournaments
    query = db().collectionGroup("games");
  }

  if (courtId) query = query.where("courtId", "==", courtId);
  if (status) query = query.where("status", "==", status);
  if (date) {
    const start = new Date(date);
    start.setHours(0, 0, 0, 0);
    const end = new Date(date);
    end.setHours(23, 59, 59, 999);
    query = query.where("scheduledTime", ">=", start).where("scheduledTime", "<=", end);
  }

  const snap = await query.get();
  res.json(snap.docs.map((d) => ({id: d.id, ...d.data()})));
}

/**
 * GET /games/:gameId
 * Query param: tournamentId (required)
 */
async function handleGetGame(
  req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const {tournamentId} = req.query as Record<string, string>;
  if (!tournamentId) {
    res.status(400).json({error: "tournamentId query param required"});
    return;
  }
  const doc = await db()
    .collection(`tournaments/${tournamentId}/games`)
    .doc(params.gameId)
    .get();
  if (!doc.exists) {
    res.status(404).json({error: "Game not found"});
    return;
  }
  res.json({id: doc.id, ...doc.data()});
}

/**
 * PATCH /games/:gameId  { status }
 * Query param: tournamentId (required)
 * Valid statuses: GameStatus.scheduled | GameStatus.inProgress | GameStatus.completed | GameStatus.cancelled
 */
async function handlePatchGame(
  req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const {tournamentId} = req.query as Record<string, string>;
  if (!tournamentId) {
    res.status(400).json({error: "tournamentId query param required"});
    return;
  }
  const VALID_STATUSES = [
    "GameStatus.scheduled",
    "GameStatus.inProgress",
    "GameStatus.completed",
    "GameStatus.cancelled",
  ];
  const {status} = req.body ?? {};
  if (!status || !VALID_STATUSES.includes(status)) {
    res.status(400).json({error: `status must be one of: ${VALID_STATUSES.join(", ")}`});
    return;
  }
  const ref = db().collection(`tournaments/${tournamentId}/games`).doc(params.gameId);
  if (!(await ref.get()).exists) {
    res.status(404).json({error: "Game not found"});
    return;
  }
  await ref.update({status, updatedAt: sv()});
  res.json({ok: true});
}

// ─── Live state handlers ──────────────────────────────────────────────────────

/** GET /games/:gameId/state */
async function handleGetState(
  _req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const doc = await db().collection("gameStates").doc(params.gameId).get();
  res.json({gameId: params.gameId, ...(doc.exists ? doc.data() : {})});
}

/**
 * PUT /games/:gameId/state
 * Body: { teamAScore?, teamBScore?, minutes?, seconds?, currentHalf?,
 *         isRunning?, halfDurationMinutes? }
 * Overwrites only provided fields (merge: true).
 */
async function handlePutState(
  req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const {
    teamAScore,
    teamBScore,
    minutes,
    seconds,
    currentHalf,
    isRunning,
    halfDurationMinutes,
  } = req.body ?? {};
  const update: Record<string, unknown> = {
    updatedAt: sv(),
    updatedBy: auth.uid,
  };
  if (teamAScore !== undefined) update.teamAScore = teamAScore;
  if (teamBScore !== undefined) update.teamBScore = teamBScore;
  if (minutes !== undefined) update.minutes = minutes;
  if (seconds !== undefined) update.seconds = seconds;
  if (currentHalf !== undefined) update.currentHalf = currentHalf;
  if (isRunning !== undefined) update.isRunning = isRunning;
  if (halfDurationMinutes !== undefined) update.halfDurationMinutes = halfDurationMinutes;
  await db().collection("gameStates").doc(params.gameId).set(update, {merge: true});
  res.json({ok: true});
}

/**
 * POST /games/:gameId/state/score  { team: "A" | "B", delta: 1 | -1 }
 */
async function handleScore(
  req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const {team, delta} = req.body ?? {};
  if (!["A", "B"].includes(team) || ![1, -1].includes(Number(delta))) {
    res.status(400).json({error: "team must be A|B and delta must be 1|-1"});
    return;
  }
  const field = team === "A" ? "teamAScore" : "teamBScore";
  await db()
    .collection("gameStates")
    .doc(params.gameId)
    .set(
      {
        [field]: admin.firestore.FieldValue.increment(Number(delta)),
        updatedAt: sv(),
        updatedBy: auth.uid,
      },
      {merge: true}
    );
  res.json({ok: true});
}

/**
 * POST /games/:gameId/state/period  { period: number }
 * Sets the half/period number. Time reset is handled client-side.
 */
async function handlePeriod(
  req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const {period} = req.body ?? {};
  if (typeof period !== "number" || period < 1) {
    res.status(400).json({error: "period must be a positive integer"});
    return;
  }
  await db()
    .collection("gameStates")
    .doc(params.gameId)
    .set(
      {
        currentHalf: period,
        updatedAt: sv(),
        updatedBy: auth.uid,
      },
      {merge: true}
    );
  res.json({ok: true});
}

// ─── Game event handlers ──────────────────────────────────────────────────────

/** GET /games/:gameId/events */
async function handleListEvents(
  _req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const snap = await db()
    .collection("gameEvents")
    .where("gameId", "==", params.gameId)
    .orderBy("timestamp")
    .get();
  res.json(snap.docs.map((d) => ({id: d.id, ...d.data()})));
}

const VALID_EVENT_TYPES = [
  "goal",
  "sevenMeterHit",
  "sevenMeterMiss",
  "yellowCard",
  "twoMinuteSuspension",
  "redCard",
  "blueCard",
  "timeout",
  "substitution",
];

/**
 * POST /games/:gameId/events
 * Body: { eventType, teamId, teamName, playerName?, playerId?,
 *         gameMinute?, half?, notes? }
 */
async function handleCreateEvent(
  req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const {
    eventType,
    teamId,
    teamName,
    playerName = "",
    playerId = null,
    gameMinute = 0,
    half = null,
    notes = null,
  } = req.body ?? {};

  if (!eventType || !VALID_EVENT_TYPES.includes(eventType)) {
    res
      .status(400)
      .json({error: `eventType must be one of: ${VALID_EVENT_TYPES.join(", ")}`});
    return;
  }
  if (!teamId || !teamName) {
    res.status(400).json({error: "teamId and teamName are required"});
    return;
  }

  const event = {
    gameId: params.gameId,
    eventType,
    teamId,
    teamName,
    playerName,
    playerId,
    gameMinute,
    half,
    notes,
    sourceUserId: auth.uid,
    timestamp: sv(),
  };
  const ref = await db().collection("gameEvents").add(event);
  res.status(201).json({id: ref.id, ...event});
}

/** DELETE /games/:gameId/events/:eventId */
async function handleDeleteEvent(
  _req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const ref = db().collection("gameEvents").doc(params.eventId);
  const doc = await ref.get();
  if (!doc.exists || doc.data()?.gameId !== params.gameId) {
    res.status(404).json({error: "Event not found"});
    return;
  }
  await ref.delete();
  res.json({ok: true});
}

// ─── Court handlers ───────────────────────────────────────────────────────────

/** GET /courts/:courtId/active-game */
async function handleCourtActiveGame(
  _req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const snap = await db()
    .collectionGroup("games")
    .where("courtId", "==", params.courtId)
    .where("status", "in", ["GameStatus.inProgress", "GameStatus.scheduled"])
    .orderBy("scheduledTime")
    .limit(1)
    .get();
  if (snap.empty) {
    res.status(404).json({error: "No active game on this court"});
    return;
  }
  res.json({id: snap.docs[0].id, ...snap.docs[0].data()});
}

/** GET /courts/:courtId/state – live state of the currently active game on this court */
async function handleCourtState(
  _req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const snap = await db()
    .collectionGroup("games")
    .where("courtId", "==", params.courtId)
    .where("status", "==", "GameStatus.inProgress")
    .limit(1)
    .get();
  if (snap.empty) {
    res.status(404).json({error: "No live game on this court"});
    return;
  }
  const gameId = snap.docs[0].id;
  const stateDoc = await db().collection("gameStates").doc(gameId).get();
  res.json({gameId, ...(stateDoc.exists ? stateDoc.data() : {})});
}

/**
 * POST /courts/:courtId/assign  { gameId }
 * Assigns a game to a court (sets courtId on the game document).
 * Query param: tournamentId (required)
 */
async function handleCourtAssign(
  req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;
  const {tournamentId} = req.query as Record<string, string>;
  if (!tournamentId) {
    res.status(400).json({error: "tournamentId query param required"});
    return;
  }
  const {gameId} = req.body ?? {};
  if (!gameId) {
    res.status(400).json({error: "gameId is required"});
    return;
  }
  const ref = db().collection(`tournaments/${tournamentId}/games`).doc(gameId);
  if (!(await ref.get()).exists) {
    res.status(404).json({error: "Game not found"});
    return;
  }
  await ref.update({courtId: params.courtId, updatedAt: sv()});
  res.json({ok: true});
}

// ─── SSE stream ───────────────────────────────────────────────────────────────

/**
 * GET /games/:gameId/stream
 * Server-Sent Events: emits "state" and "gameEvent" events in real time.
 * Keep-alive comment every 25 s to prevent proxy timeouts.
 */
async function handleStream(
  req: Request,
  res: Response,
  auth: AuthContext | null,
  params: Params
): Promise<void> {
  if (!requireAuth(auth, res)) return;

  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no"); // disable nginx buffering
  res.flushHeaders();

  const keepAlive = setInterval(() => {
    res.write(":keepalive\n\n");
  }, 25_000);

  // Stream live state changes
  const unsubState = db()
    .collection("gameStates")
    .doc(params.gameId)
    .onSnapshot((snap) => {
      if (snap.exists) {
        res.write(
          `event: state\ndata: ${JSON.stringify({gameId: params.gameId, ...snap.data()})}\n\n`
        );
      }
    });

  // Stream new game events
  const unsubEvents = db()
    .collection("gameEvents")
    .where("gameId", "==", params.gameId)
    .onSnapshot((snap) => {
      snap.docChanges().forEach((change) => {
        if (change.type === "added") {
          res.write(
            `event: gameEvent\ndata: ${JSON.stringify({id: change.doc.id, ...change.doc.data()})}\n\n`
          );
        }
      });
    });

  req.on("close", () => {
    clearInterval(keepAlive);
    unsubState();
    unsubEvents();
  });
}

// ─── Lightweight router ───────────────────────────────────────────────────────

type RouteTuple = [
  string,
  RegExp,
  string[],
  Handler,
];

function route(method: string, path: string, fn: Handler): RouteTuple {
  const names: string[] = [];
  const pattern = new RegExp(
    "^" +
      path.replace(/:([^/]+)/g, (_, n: string) => {
        names.push(n);
        return "([^/]+)";
      }) +
      "/?$"
  );
  return [method, pattern, names, fn];
}

const ROUTES: RouteTuple[] = [
  // Auth
  route("POST",   "/login",                         (req, res, auth) => handleLogin(req, res)),
  route("POST",   "/logout",                        (req, res, auth) => handleLogout(req, res, auth)),
  route("GET",    "/me",                            (req, res, auth) => handleMe(req, res, auth)),
  // Courts
  route("GET",    "/courts",                        (req, res, auth) => handleListCourts(req, res, auth)),
  // Games
  route("GET",    "/games",                         (req, res, auth) => handleListGames(req, res, auth)),
  route("GET",    "/games/:gameId",                 (req, res, auth, p) => handleGetGame(req, res, auth, p)),
  route("PATCH",  "/games/:gameId",                 (req, res, auth, p) => handlePatchGame(req, res, auth, p)),
  // Live state (time is client-managed – server stores only what the scoreboard pushes)
  route("GET",    "/games/:gameId/state",           (req, res, auth, p) => handleGetState(req, res, auth, p)),
  route("PUT",    "/games/:gameId/state",           (req, res, auth, p) => handlePutState(req, res, auth, p)),
  route("POST",   "/games/:gameId/state/score",     (req, res, auth, p) => handleScore(req, res, auth, p)),
  route("POST",   "/games/:gameId/state/period",    (req, res, auth, p) => handlePeriod(req, res, auth, p)),
  // Events
  route("GET",    "/games/:gameId/events",          (req, res, auth, p) => handleListEvents(req, res, auth, p)),
  route("POST",   "/games/:gameId/events",          (req, res, auth, p) => handleCreateEvent(req, res, auth, p)),
  route("DELETE", "/games/:gameId/events/:eventId", (req, res, auth, p) => handleDeleteEvent(req, res, auth, p)),
  // SSE stream
  route("GET",    "/games/:gameId/stream",          (req, res, auth, p) => handleStream(req, res, auth, p)),
  // Courts
  route("GET",    "/courts/:courtId/active-game",   (req, res, auth, p) => handleCourtActiveGame(req, res, auth, p)),
  route("GET",    "/courts/:courtId/state",         (req, res, auth, p) => handleCourtState(req, res, auth, p)),
  route("POST",   "/courts/:courtId/assign",        (req, res, auth, p) => handleCourtAssign(req, res, auth, p)),
];

// ─── Cloud Function export ────────────────────────────────────────────────────

/**
 * scoreboardApi – single HTTP function that handles all scoreboard routes.
 *
 * Call as:
 *   POST  https://REGION-PROJECT.cloudfunctions.net/scoreboardApi/login
 *   GET   https://REGION-PROJECT.cloudfunctions.net/scoreboardApi/games?tournamentId=…
 *   etc.
 */
export const scoreboardApi = onRequest(
  {cors: true, timeoutSeconds: 3600, memory: "256MiB", secrets: ["GBO_WEB_API_KEY"]},
  async (req, res) => {
    // Resolve auth once for all requests (login endpoint ignores it)
    const auth = await resolveAuth(req).catch(() => null);
    const path = req.path || "/";

    for (const [method, pattern, names, handler] of ROUTES) {
      if (method !== req.method) continue;
      const match = path.match(pattern);
      if (!match) continue;
      const params: Params = {};
      names.forEach((n, i) => {
        params[n] = match[i + 1];
      });
      try {
        await handler(req, res, auth, params);
      } catch (err) {
        console.error(`scoreboardApi error [${method} ${path}]:`, err);
        if (!res.headersSent) {
          res.status(500).json({error: "Internal server error"});
        }
      }
      return;
    }
    res.status(404).json({error: `Route not found: ${req.method} ${path}`});
  }
);
