/**
 * YouTube Live-Broadcast Automation + Stories
 *
 * - youtubeOAuthCallback (HTTP):
 *     OAuth 2.0 redirect handler. Exchanges the auth code for a refresh token
 *     and stores it in `config/youtube_oauth` together with channel metadata.
 *
 * - createYoutubeBroadcast (callable, admin only):
 *     Uses the stored refresh token to create a YouTube live broadcast +
 *     stream, binds them, writes the embed URL into the tournament document,
 *     and returns RTMP URL + stream key for use in OBS / vMix.
 *
 * - getYoutubeAuthUrl (callable, admin only):
 *     Returns the Google OAuth consent URL (client-ID stays server-side).
 *
 * - initiateYoutubeUpload (callable, admin/teamRHD):
 *     Starts a resumable YouTube video upload. Creates a Firestore story doc
 *     with status 'uploading' and returns the upload URL for direct XHR upload.
 *
 * - finalizeStory (callable, admin/teamRHD):
 *     Marks a story doc as 'active' after the client has finished uploading.
 *
 * Required Firebase secrets:
 *   - YOUTUBE_CLIENT_ID         (Web OAuth client ID)
 *   - YOUTUBE_CLIENT_SECRET     (Web OAuth client secret)
 *   - YOUTUBE_REDIRECT_URI      (URL of `youtubeOAuthCallback`)
 *
 * Firestore docs:
 *   config/youtube_oauth: { refreshToken, channelId, channelTitle, updatedAt, connectedBy }
 *   stories/{id}: { title, youtubeVideoId, uploadedBy, createdAt, expiresAt?, order, status }
 */

import {onRequest, onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {google} from "googleapis";

const YOUTUBE_CLIENT_ID = defineSecret("YOUTUBE_CLIENT_ID");
const YOUTUBE_CLIENT_SECRET = defineSecret("YOUTUBE_CLIENT_SECRET");
const YOUTUBE_REDIRECT_URI = defineSecret("YOUTUBE_REDIRECT_URI");

const REGION = "europe-west1";
const OAUTH_DOC = "config/youtube_oauth";
const SCOPES = ["https://www.googleapis.com/auth/youtube"];

/**
 * Build an OAuth2 client from secrets.
 */
function buildOAuthClient(): InstanceType<typeof google.auth.OAuth2> {
  return new google.auth.OAuth2(
    YOUTUBE_CLIENT_ID.value(),
    YOUTUBE_CLIENT_SECRET.value(),
    YOUTUBE_REDIRECT_URI.value(),
  );
}

/**
 * GET /youtubeOAuthCallback?code=...&state=<uid>
 *
 * Receives the OAuth redirect, exchanges the code, persists refresh token +
 * channel metadata, and returns a small HTML page. Open this from the Flutter
 * client via `url_launcher` after the user grants consent.
 */
export const youtubeOAuthCallback = onRequest(
  {
    region: REGION,
    secrets: [YOUTUBE_CLIENT_ID, YOUTUBE_CLIENT_SECRET, YOUTUBE_REDIRECT_URI],
    cors: true,
  },
  async (req, res) => {
    const code = (req.query.code as string | undefined) ?? "";
    const state = (req.query.state as string | undefined) ?? "";
    const error = req.query.error as string | undefined;

    if (error) {
      res.status(400).send(renderHtml(
        "Verbindung abgebrochen",
        `Google meldete: <code>${escapeHtml(error)}</code>`,
      ));
      return;
    }
    if (!code) {
      res.status(400).send(renderHtml(
        "Fehlender Code",
        "Es wurde kein Authorization-Code übermittelt.",
      ));
      return;
    }

    try {
      const oauth2 = buildOAuthClient();
      const {tokens} = await oauth2.getToken(code);
      oauth2.setCredentials(tokens);

      if (!tokens.refresh_token) {
        res.status(400).send(renderHtml(
          "Kein Refresh-Token erhalten",
          "Bitte verbinde das Konto erneut und stelle sicher, dass " +
          "der Consent-Screen mit <code>access_type=offline</code> und " +
          "<code>prompt=consent</code> aufgerufen wurde.",
        ));
        return;
      }

      const youtube = google.youtube({version: "v3", auth: oauth2});
      const channels = await youtube.channels.list({
        part: ["id", "snippet"],
        mine: true,
      });
      const channel = channels.data.items?.[0];
      if (!channel) {
        res.status(400).send(renderHtml(
          "Kein YouTube-Channel gefunden",
          "Das verbundene Google-Konto hat keinen YouTube-Channel.",
        ));
        return;
      }

      await admin.firestore().doc(OAUTH_DOC).set({
        refreshToken: tokens.refresh_token,
        channelId: channel.id,
        channelTitle: channel.snippet?.title ?? "",
        connectedBy: state || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).send(renderHtml(
        "YouTube verbunden",
        `Channel: <strong>${escapeHtml(channel.snippet?.title ?? "")}` +
        "</strong><br/>Du kannst dieses Fenster jetzt schließen.",
      ));
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      res.status(500).send(renderHtml(
        "Fehler beim Verbinden",
        `<pre>${escapeHtml(msg)}</pre>`,
      ));
    }
  },
);

/**
 * Callable: createYoutubeBroadcast
 *
 * Input:
 *   {
 *     tournamentId: string,
 *     title?: string,
 *     description?: string,
 *     scheduledStartTime?: string  // ISO 8601, default = now
 *     privacyStatus?: "public" | "unlisted" | "private", // default unlisted
 *   }
 *
 * Output:
 *   {
 *     broadcastId: string,
 *     streamId: string,
 *     watchUrl: string,
 *     embedUrl: string,
 *     rtmpUrl: string,
 *     streamKey: string,
 *   }
 *
 * Side effects:
 *   - Updates `tournaments/{id}` with `livestreamUrl`, `livestreamEnabled`,
 *     `livestreamYoutubeBroadcastId`.
 */
export const createYoutubeBroadcast = onCall(
  {
    region: REGION,
    secrets: [YOUTUBE_CLIENT_ID, YOUTUBE_CLIENT_SECRET, YOUTUBE_REDIRECT_URI],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login erforderlich.");
    }
    // Admin check
    const uid = request.auth.uid;
    const userDoc = await admin.firestore().doc(`users/${uid}`).get();
    const roles = (userDoc.data()?.roles ?? []) as string[];
    if (!roles.includes("admin")) {
      throw new HttpsError(
        "permission-denied",
        "Nur Admins dürfen Streams erstellen.",
      );
    }

    const {
      tournamentId,
      title,
      description,
      scheduledStartTime,
      privacyStatus,
    } = (request.data ?? {}) as {
      tournamentId?: string;
      title?: string;
      description?: string;
      scheduledStartTime?: string;
      privacyStatus?: string;
    };

    if (!tournamentId) {
      throw new HttpsError(
        "invalid-argument",
        "tournamentId fehlt.",
      );
    }

    const oauthDoc = await admin.firestore().doc(OAUTH_DOC).get();
    if (!oauthDoc.exists || !oauthDoc.data()?.refreshToken) {
      throw new HttpsError(
        "failed-precondition",
        "YouTube-Konto ist nicht verbunden.",
      );
    }
    const refreshToken = oauthDoc.data()?.refreshToken as string;

    const oauth2 = buildOAuthClient();
    oauth2.setCredentials({refresh_token: refreshToken});
    const youtube = google.youtube({version: "v3", auth: oauth2});

    const tournamentRef = admin.firestore().doc(`tournaments/${tournamentId}`);
    const tournamentSnap = await tournamentRef.get();
    if (!tournamentSnap.exists) {
      throw new HttpsError("not-found", "Turnier nicht gefunden.");
    }
    const tournamentName = (tournamentSnap.data()?.name as string) ?? "Turnier";

    const startIso = scheduledStartTime ?? new Date().toISOString();
    const finalTitle = (title && title.trim().length > 0) ?
      title :
      `${tournamentName} – Livestream`;
    const finalPrivacy = ["public", "unlisted", "private"]
      .includes(privacyStatus ?? "") ?
      (privacyStatus as string) :
      "unlisted";

    try {
      // 1) Create broadcast
      const broadcast = await youtube.liveBroadcasts.insert({
        part: ["snippet", "contentDetails", "status"],
        requestBody: {
          snippet: {
            title: finalTitle,
            description: description ?? "",
            scheduledStartTime: startIso,
          },
          contentDetails: {
            enableAutoStart: true,
            enableAutoStop: true,
            enableDvr: true,
            enableEmbed: true,
          },
          status: {
            privacyStatus: finalPrivacy,
            selfDeclaredMadeForKids: false,
          },
        },
      });
      const broadcastId = broadcast.data.id;
      if (!broadcastId) {
        throw new HttpsError("internal", "Broadcast wurde nicht erstellt.");
      }

      // 2) Create stream
      const stream = await youtube.liveStreams.insert({
        part: ["snippet", "cdn", "contentDetails"],
        requestBody: {
          snippet: {title: finalTitle},
          cdn: {
            frameRate: "variable",
            ingestionType: "rtmp",
            resolution: "variable",
          },
        },
      });
      const streamId = stream.data.id;
      const ingestion = stream.data.cdn?.ingestionInfo;
      if (!streamId || !ingestion) {
        throw new HttpsError("internal", "Stream wurde nicht erstellt.");
      }

      // 3) Bind broadcast ↔ stream
      await youtube.liveBroadcasts.bind({
        id: broadcastId,
        part: ["id", "contentDetails"],
        streamId: streamId,
      });

      const watchUrl = `https://www.youtube.com/watch?v=${broadcastId}`;
      const embedUrl =
        `https://www.youtube.com/embed/${broadcastId}?playsinline=1`;
      const rtmpUrl = ingestion.ingestionAddress ?? "";
      const streamKey = ingestion.streamName ?? "";

      // 4) Persist on tournament
      await tournamentRef.update({
        livestreamUrl: watchUrl,
        livestreamEnabled: true,
        livestreamYoutubeBroadcastId: broadcastId,
      });

      return {
        broadcastId,
        streamId,
        watchUrl,
        embedUrl,
        rtmpUrl,
        streamKey,
      };
    } catch (e: unknown) {
      if (e instanceof HttpsError) throw e;
      const msg = e instanceof Error ? e.message : String(e);
      throw new HttpsError("internal", `YouTube API-Fehler: ${msg}`);
    }
  },
);

/**
 * Callable: getYoutubeAuthUrl (admin only)
 *
 * Generates and returns the Google OAuth consent URL so the Flutter client
 * does NOT need to know the client-ID or redirect-URI. The caller just
 * opens the returned URL in the browser.
 *
 * Returns: { url: string }
 */
export const getYoutubeAuthUrl = onCall(
  {
    region: REGION,
    secrets: [YOUTUBE_CLIENT_ID, YOUTUBE_REDIRECT_URI],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login erforderlich.");
    }
    const uid = request.auth.uid;
    const userDoc = await admin.firestore().doc(`users/${uid}`).get();
    const roles = (userDoc.data()?.roles ?? []) as string[];
    if (!roles.includes("admin")) {
      throw new HttpsError("permission-denied", "Nur Admins.");
    }

    const oauth2 = new google.auth.OAuth2(
      YOUTUBE_CLIENT_ID.value(),
      undefined,
      YOUTUBE_REDIRECT_URI.value(),
    );
    const url = oauth2.generateAuthUrl({
      access_type: "offline",
      prompt: "consent",
      include_granted_scopes: true,
      scope: SCOPES,
      state: uid,
    });
    return {url};
  },
);

/**
 * Callable: initiateYoutubeUpload (admin/teamRHD)
 *
 * Starts a resumable YouTube video upload session and creates a Firestore
 * story document with status='uploading'. The client then uploads the file
 * bytes directly to the returned `uploadUrl` via XHR (no Cloud Function
 * proxy needed), and calls `finalizeStory` when done.
 *
 * Input:  { title, description?, privacyStatus?, expiresAt? (ISO string) }
 * Returns: { uploadUrl, videoId, storyId }
 */
export const initiateYoutubeUpload = onCall(
  {
    region: REGION,
    secrets: [YOUTUBE_CLIENT_ID, YOUTUBE_CLIENT_SECRET, YOUTUBE_REDIRECT_URI],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login erforderlich.");
    }
    const uid = request.auth.uid;
    const userDoc = await admin.firestore().doc(`users/${uid}`).get();
    const roles = (userDoc.data()?.roles ?? []) as string[];
    if (!roles.includes("admin") && !roles.includes("teamRHD")) {
      throw new HttpsError("permission-denied", "Nur Admins und teamRHD.");
    }

    const oauthDoc = await admin.firestore().doc(OAUTH_DOC).get();
    if (!oauthDoc.exists || !oauthDoc.data()?.refreshToken) {
      throw new HttpsError(
        "failed-precondition",
        "YouTube-Konto ist nicht verbunden. Bitte zuerst in 'YouTube-Verbindung' verknüpfen.",
      );
    }

    const {
      title,
      description,
      privacyStatus,
      expiresAt,
    } = (request.data ?? {}) as {
      title?: string;
      description?: string;
      privacyStatus?: string;
      expiresAt?: string;
    };

    if (!title || title.trim().length === 0) {
      throw new HttpsError("invalid-argument", "title fehlt.");
    }

    const oauth2 = buildOAuthClient();
    oauth2.setCredentials({refresh_token: oauthDoc.data()?.refreshToken});

    const finalPrivacy = ["public", "unlisted", "private"].includes(
      privacyStatus ?? "",
    ) ?
      (privacyStatus as string) :
      "unlisted";

    // Use the YouTube Data API to initiate a resumable upload session.
    // We call the endpoint manually because the googleapis client doesn't
    // expose resumable upload URLs directly for videos.insert.
    const tokenRes = await oauth2.getAccessToken();
    const accessToken = tokenRes.token;
    if (!accessToken) {
      throw new HttpsError("internal", "Kein Access-Token erhalten.");
    }

    const metadata = {
      snippet: {
        title: title.trim(),
        description: description ?? "",
        categoryId: "17", // Sports
      },
      status: {
        privacyStatus: finalPrivacy,
        selfDeclaredMadeForKids: false,
        embeddable: true,
      },
    };

    // Initiate resumable upload — returns the upload URL in the Location header.
    const initResponse = await fetch(
      "https://www.googleapis.com/upload/youtube/v3/videos" +
      "?uploadType=resumable&part=snippet,status",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json; charset=UTF-8",
          "X-Upload-Content-Type": "video/*",
        },
        body: JSON.stringify(metadata),
      },
    );

    if (!initResponse.ok) {
      const err = await initResponse.text();
      throw new HttpsError(
        "internal",
        `YouTube Upload Init fehlgeschlagen: ${err}`,
      );
    }

    const uploadUrl = initResponse.headers.get("Location");
    if (!uploadUrl) {
      throw new HttpsError("internal", "Kein Upload-URL erhalten.");
    }

    // Extract videoId from the upload URL (it's embedded as a query param).
    const videoIdMatch = uploadUrl.match(/[?&]upload_id=([^&]+)/);
    // videoId is not available until upload completes; we use a placeholder.
    // The client must call finalizeStory which fetches the real videoId.
    const uploadId = videoIdMatch ? videoIdMatch[1] : "pending";

    // Create Firestore story doc
    const storyRef = admin.firestore().collection("stories").doc();
    const storyData = {
      title: title.trim(),
      youtubeVideoId: null, // set by finalizeStory
      uploadedBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: expiresAt ? new Date(expiresAt) : null,
      order: 0,
      status: "uploading",
      uploadUrl, // temp, removed by finalizeStory
      uploadId,
    };
    await storyRef.set(storyData);

    return {uploadUrl, storyId: storyRef.id};
  },
);

/**
 * Callable: finalizeStory (admin/teamRHD)
 *
 * Called by the client after the XHR video upload is complete. Fetches the
 * newly uploaded video's ID from YouTube (via the upload URL), updates the
 * Firestore story doc with the real videoId and sets status='active'.
 *
 * Input:  { storyId, videoId }
 * Returns: { success: true }
 */
export const finalizeStory = onCall(
  {
    region: REGION,
    secrets: [YOUTUBE_CLIENT_ID, YOUTUBE_CLIENT_SECRET, YOUTUBE_REDIRECT_URI],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login erforderlich.");
    }
    const uid = request.auth.uid;
    const userDoc = await admin.firestore().doc(`users/${uid}`).get();
    const roles = (userDoc.data()?.roles ?? []) as string[];
    if (!roles.includes("admin") && !roles.includes("teamRHD")) {
      throw new HttpsError("permission-denied", "Nur Admins und teamRHD.");
    }

    const {storyId, videoId} = (request.data ?? {}) as {
      storyId?: string;
      videoId?: string;
    };
    if (!storyId) throw new HttpsError("invalid-argument", "storyId fehlt.");
    if (!videoId) throw new HttpsError("invalid-argument", "videoId fehlt.");

    const storyRef = admin.firestore().doc(`stories/${storyId}`);
    const snap = await storyRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Story nicht gefunden.");
    }

    // Determine the next display order (highest existing + 1)
    const storiesSnap = await admin.firestore()
      .collection("stories")
      .orderBy("order", "desc")
      .limit(1)
      .get();
    const maxOrder = storiesSnap.empty ?
      0 :
      (storiesSnap.docs[0].data().order as number ?? 0);

    await storyRef.update({
      youtubeVideoId: videoId,
      status: "active",
      order: maxOrder + 1,
      uploadUrl: admin.firestore.FieldValue.delete(),
      uploadId: admin.firestore.FieldValue.delete(),
    });

    return {success: true};
  },
);

/**
 * Callable: processStoryUpload (admin/teamRHD)
 *
 * Server-side upload pipeline that avoids CORS issues with the YouTube API:
 *   1. Downloads the video from Firebase Storage (uploaded by the client)
 *   2. Initiates a resumable YouTube upload session
 *   3. PUTs the bytes to YouTube (server-side — no CORS)
 *   4. Creates the Firestore story doc with status='active'
 *   5. Deletes the temporary Storage file
 *
 * Input:  { storagePath, title, privacyStatus?, expiresAt? (ISO string) }
 * Returns: { storyId, videoId }
 */
export const processStoryUpload = onCall(
  {
    region: REGION,
    secrets: [YOUTUBE_CLIENT_ID, YOUTUBE_CLIENT_SECRET, YOUTUBE_REDIRECT_URI],
    timeoutSeconds: 540,
    memory: "1GiB" as const,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login erforderlich.");
    }
    const uid = request.auth.uid;
    const userDoc = await admin.firestore().doc(`users/${uid}`).get();
    const roles = (userDoc.data()?.roles ?? []) as string[];
    if (!roles.includes("admin") && !roles.includes("teamRHD")) {
      throw new HttpsError("permission-denied", "Nur Admins und teamRHD.");
    }

    const {storagePath, title, privacyStatus, expiresAt} =
      (request.data ?? {}) as {
        storagePath?: string;
        title?: string;
        privacyStatus?: string;
        expiresAt?: string;
      };
    if (!storagePath) throw new HttpsError("invalid-argument", "storagePath fehlt.");
    if (!title || !title.trim()) throw new HttpsError("invalid-argument", "title fehlt.");

    // 1. Download from Firebase Storage via Admin SDK (bypasses storage rules)
    const bucket = admin.storage().bucket();
    const storageFile = bucket.file(storagePath);
    const [[fileBuffer], [storageMeta]] = await Promise.all([
      storageFile.download(),
      storageFile.getMetadata(),
    ]);
    const contentType = (storageMeta.contentType as string | undefined) ?? "video/mp4";

    // 2. Build OAuth client
    const oauthDoc = await admin.firestore().doc(OAUTH_DOC).get();
    if (!oauthDoc.exists || !oauthDoc.data()?.refreshToken) {
      throw new HttpsError(
        "failed-precondition",
        "YouTube-Konto ist nicht verbunden.",
      );
    }
    const oauth2 = buildOAuthClient();
    oauth2.setCredentials({refresh_token: oauthDoc.data()?.refreshToken});
    const tokenRes = await oauth2.getAccessToken();
    const accessToken = tokenRes.token;
    if (!accessToken) throw new HttpsError("internal", "Kein Access-Token.");

    const finalPrivacy = ["public", "unlisted", "private"].includes(
      privacyStatus ?? "",
    ) ? (privacyStatus as string) : "unlisted";

    const videoMetadata = {
      snippet: {
        title: title.trim(),
        description: "",
        categoryId: "17",
      },
      status: {
        privacyStatus: finalPrivacy,
        selfDeclaredMadeForKids: false,
        embeddable: true,
      },
    };

    // 3. Initiate resumable upload session
    const initRes = await fetch(
      "https://www.googleapis.com/upload/youtube/v3/videos" +
      "?uploadType=resumable&part=snippet,status",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json; charset=UTF-8",
          "X-Upload-Content-Type": contentType,
          "X-Upload-Content-Length": String(fileBuffer.length),
        },
        body: JSON.stringify(videoMetadata),
      },
    );
    if (!initRes.ok) {
      const err = await initRes.text();
      throw new HttpsError("internal", `Upload Init fehlgeschlagen: ${err}`);
    }
    const uploadUrl = initRes.headers.get("Location");
    if (!uploadUrl) throw new HttpsError("internal", "Kein Upload-URL.");

    // 4. Upload bytes to YouTube (server-side — no browser CORS involved)
    const uploadRes = await fetch(uploadUrl, {
      method: "PUT",
      headers: {
        "Content-Type": contentType,
        "Content-Length": String(fileBuffer.length),
      },
      body: new Uint8Array(fileBuffer),
    });
    if (uploadRes.status < 200 || uploadRes.status >= 300) {
      const err = await uploadRes.text();
      throw new HttpsError("internal", `YouTube Upload fehlgeschlagen: ${err}`);
    }
    const uploadBody = await uploadRes.json() as {id?: string};
    const videoId = uploadBody.id;
    if (!videoId) throw new HttpsError("internal", "Kein videoId von YouTube.");

    // 5. Delete temporary Storage file (fire-and-forget)
    storageFile.delete().catch(() => undefined);

    // 6. Determine next display order
    const storiesSnap = await admin.firestore()
      .collection("stories")
      .orderBy("order", "desc")
      .limit(1)
      .get();
    const maxOrder = storiesSnap.empty ?
      0 :
      (storiesSnap.docs[0].data().order as number ?? 0);

    // 7. Create Firestore story doc
    const storyRef = admin.firestore().collection("stories").doc();
    await storyRef.set({
      title: title.trim(),
      youtubeVideoId: videoId,
      uploadedBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: expiresAt ? new Date(expiresAt) : null,
      order: maxOrder + 1,
      status: "active",
    });

    return {storyId: storyRef.id, videoId};
  },
);

/**
 * Tiny HTML helpers for the OAuth landing page.
 */
function renderHtml(title: string, body: string): string {
  return `<!doctype html><html lang="de"><head><meta charset="utf-8"/>
<title>${escapeHtml(title)}</title>
<style>
  body{font-family:system-ui,sans-serif;background:#111;color:#eee;
       display:flex;align-items:center;justify-content:center;
       height:100vh;margin:0}
  .card{max-width:520px;background:#1c1c1c;padding:32px 36px;
        border:1px solid #333;border-radius:6px;line-height:1.55}
  h1{margin:0 0 12px;font-size:20px}
  code,pre{background:#000;padding:2px 6px;border-radius:3px;
           color:#ffd665}
</style></head><body><div class="card">
<h1>${escapeHtml(title)}</h1><div>${body}</div></div></body></html>`;
}

function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;",
  }[c] as string));
}
