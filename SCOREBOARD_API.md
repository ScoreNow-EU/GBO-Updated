# Scoreboard API

**Base URL:** `https://REGION-PROJECT.cloudfunctions.net/scoreboardApi`  
**Auth:** `Authorization: Bearer <token>` bei allen Endpunkten außer `/login`  
**Content-Type:** `application/json`

> ⚠️ **Zeit ist client-seitig.** Der Server berechnet keine Zeit. Das Scoreboard-Gerät führt den Timer lokal und kann optional `minutes`, `seconds`, `isRunning` via `PUT /state` für SSE-Anzeige synchronisieren.

---

## 🔐 Auth

### `POST /login`

**Body:**
```json
{
  "email": "name@example.com",
  "password": "meinPasswort"
}
```

Benötigt ein bestehendes Firebase-Auth-Konto mit Rolle `admin` oder `scoringTablet`.

**Response `200`:**
```json
{
  "token": "<firebase-id-token>",
  "refreshToken": "<firebase-refresh-token>",
  "expiresIn": 3600,
  "uid": "abc123",
  "email": "name@example.com",
  "firstName": "Max",
  "lastName": "Mustermann",
  "role": "admin",
  "roles": ["admin"]
}
```

> Das zurückgegebene `token` ist ein **Firebase ID Token** (JWT, gültig **1 Stunde**).
> Nach Ablauf über den `refreshToken` erneuern (siehe unten).

---

### Token erneuern

Firebase ID Tokens laufen nach **1 Stunde** ab. Neuen Token ohne erneuten Login anfordern:

```http
POST https://securetoken.googleapis.com/v1/token?key=FIREBASE_WEB_API_KEY
Content-Type: application/json

{
  "grant_type": "refresh_token",
  "refresh_token": "<refreshToken aus /login>"
}
```

**Response:** `{ "id_token": "...", "refresh_token": "...", "expires_in": "3600" }`  
Den neuen `id_token` danach als `Bearer`-Token verwenden.

---

### `POST /logout`

Invalidiert alle Refresh Tokens des Accounts (serverseitig). Kein Body nötig.

**Response `200`:** `{ "ok": true }`

---

### `GET /me`

Gibt das eigene Benutzerprofil zurück.

**Response `200`:**
```json
{
  "uid": "abc123",
  "email": "name@example.com",
  "firstName": "Max",
  "lastName": "Mustermann",
  "roles": ["admin"],
  "isActive": true
}
```

---

## 🏟️ Felder (Courts)

### `GET /courts`

Liste aller Felder.

**Response `200`:** `[ { "id": "court-a", "name": "Feld 1" }, … ]`

---

## 🎮 Spiele

### `GET /games`

Alle Parameter sind **optional**. Ohne Filter werden alle Spiele aller Turniere zurückgegeben.

**Query-Parameter:**

| Parameter | Pflicht | Beschreibung |
|-----------|---------|---------------|
| `tournamentId` | ❌ | Filtert Spiele eines Turniers |
| `courtId` | ❌ | Filtert Spiele eines Feldes |
| `status` | ❌ | z. B. `GameStatus.inProgress` |
| `date` | ❌ | ISO-Datum, z. B. `2026-06-29` |

**Beispiele:**
```
GET /games
GET /games?courtId=court-a
GET /games?tournamentId=turnier-xyz&status=GameStatus.inProgress
GET /games?date=2026-06-29
```

**Response `200`:** Array von Spielobjekten

---

### `GET /games/:gameId`

**Query:** `tournamentId` (Pflicht)

**Response `200`:**
```json
{
  "id": "game-abc",
  "tournamentId": "turnier-xyz",
  "teamAName": "RSV Berlin",
  "teamBName": "RHC Hannover",
  "status": "GameStatus.inProgress",
  "courtId": "court-a",
  "scheduledTime": "2026-06-29T10:00:00Z"
}
```

---

### `PATCH /games/:gameId`

**Query:** `tournamentId` (Pflicht)

**Body:**
```json
{ "status": "GameStatus.inProgress" }
```

**Gültige Status-Werte:**

| Wert | Bedeutung |
|------|-----------|
| `GameStatus.scheduled` | Angesetzt |
| `GameStatus.inProgress` | Läuft |
| `GameStatus.completed` | Beendet |
| `GameStatus.cancelled` | Abgebrochen |

**Response `200`:** `{ "ok": true }`

---

## 📊 Live-State

> Zeit (`minutes`, `seconds`, `isRunning`) wird **lokal** beim Scoreboard-Gerät verwaltet. Der Server speichert nur was gesendet wird – er berechnet nichts.

### `GET /games/:gameId/state`

**Response `200`:**
```json
{
  "gameId": "game-abc",
  "teamAScore": 5,
  "teamBScore": 3,
  "currentHalf": 1,
  "halfDurationMinutes": 15,
  "minutes": 12,
  "seconds": 34,
  "isRunning": true,
  "updatedAt": "...",
  "updatedBy": "scoreboard-feld1"
}
```

---

### `PUT /games/:gameId/state`

Schreibt beliebige State-Felder (Merge – nicht vorhandene Felder bleiben erhalten). Zeitfelder sind **optional**.

**Body:**
```json
{
  "teamAScore": 5,
  "teamBScore": 3,
  "currentHalf": 1,
  "halfDurationMinutes": 15,
  "minutes": 12,
  "seconds": 34,
  "isRunning": true
}
```

**Response `200`:** `{ "ok": true }`

---

### `POST /games/:gameId/state/score`

Atomares Tor-Inkrement oder -Korrektur.

**Body:**
```json
{ "team": "A", "delta": 1 }
```

| Feld | Werte |
|------|-------|
| `team` | `"A"` oder `"B"` |
| `delta` | `1` (Tor) oder `-1` (Korrektur) |

**Response `200`:** `{ "ok": true }`

---

### `POST /games/:gameId/state/period`

Setzt die Halbzeit-Nummer. **Zeitreset erfolgt lokal beim Scoreboard-Gerät.**

**Body:**
```json
{ "period": 2 }
```

**Response `200`:** `{ "ok": true }`

---

## 📋 Spielereignisse

### `GET /games/:gameId/events`

Alle Ereignisse eines Spiels, chronologisch aufsteigend.

**Response `200`:** Array von Ereignisobjekten

---

### `POST /games/:gameId/events`

**Body:**
```json
{
  "eventType": "goal",
  "teamId": "team-abc",
  "teamName": "RSV Berlin",
  "playerName": "Max Mustermann",
  "playerId": "player-xyz",
  "gameMinute": 12,
  "half": 1,
  "notes": null
}
```

**Pflichtfelder:** `eventType`, `teamId`, `teamName`  
**Optionale Felder:** `playerName`, `playerId`, `gameMinute`, `half`, `notes`

**Gültige `eventType`-Werte:**

| Wert | Bedeutung |
|------|-----------|
| `goal` | Tor |
| `sevenMeterHit` | 7m Treffer |
| `sevenMeterMiss` | 7m Verfehlt |
| `yellowCard` | Gelbe Karte |
| `twoMinuteSuspension` | 2-Min Hinausstellung |
| `redCard` | Rote Karte |
| `blueCard` | Blaue Karte |
| `timeout` | Auszeit |
| `substitution` | Wechsel |

**Response `201`:**
```json
{
  "id": "event-xyz",
  "gameId": "game-abc",
  "eventType": "goal",
  "teamId": "team-abc",
  "teamName": "RSV Berlin",
  "playerName": "Max Mustermann",
  "gameMinute": 12,
  "half": 1,
  "sourceUserId": "uid-abc",
  "timestamp": "..."
}
```

---

### `DELETE /games/:gameId/events/:eventId`

Ereignis rückgängig machen.

**Response `200`:** `{ "ok": true }`

---

## 🏟️ Feld-basiert

### `GET /courts/:courtId/active-game`

Gibt das nächste angesetzte oder aktuell laufende Spiel auf diesem Feld zurück.

**Response `200`:** Spielobjekt  
**Response `404`:** `{ "error": "No active game on this court" }`

---

### `GET /courts/:courtId/state`

Live-State des aktuell laufenden Spiels auf diesem Feld.

**Response `200`:** State-Objekt mit `gameId`  
**Response `404`:** `{ "error": "No live game on this court" }`

---

### `POST /courts/:courtId/assign`

Weist ein Spiel einem Feld zu (setzt `courtId` im Spieldokument).

**Query:** `tournamentId` (Pflicht)

**Body:**
```json
{ "gameId": "game-abc" }
```

**Response `200`:** `{ "ok": true }`

---

## 📡 Echtzeit (Server-Sent Events)

### `GET /games/:gameId/stream`

Öffnet eine SSE-Verbindung. Der Server pusht Änderungen sobald sie in Firestore geschrieben werden.

**Emittierte Event-Typen:**

```
event: state
data: { "gameId": "game-abc", "teamAScore": 5, "teamBScore": 3, "currentHalf": 1, ... }

event: gameEvent
data: { "id": "event-xyz", "eventType": "goal", "teamName": "RSV Berlin", "gameMinute": 12, ... }
```

**Keep-Alive:** Alle 25 Sekunden wird ein `:keepalive` Kommentar gesendet um Proxy-Timeouts zu verhindern.  
**Verbindung schließen:** Automatisches Unsubscribe von Firestore-Listenern.

---

## ⚠️ Fehler-Responses

| HTTP-Code | Bedeutung |
|-----------|-----------|
| `400` | Ungültige oder fehlende Parameter |
| `401` | Kein Token oder Token abgelaufen/invalidiert |
| `403` | Fehlende Admin-Berechtigung |
| `404` | Ressource nicht gefunden |
| `500` | Interner Serverfehler |

Alle Fehler haben das Format: `{ "error": "Beschreibung" }`

---

## 🔧 Setup

### 1. Secret setzen

```bash
firebase functions:secrets:set FIREBASE_WEB_API_KEY
```

`FIREBASE_WEB_API_KEY` findest du in der Firebase Console unter  
**Projekteinstellungen → Allgemein → Web-API-Schlüssel**.

### 2. Benutzerrolle vergeben

Der anmeldende Account braucht die Rolle `admin` oder `scoringTablet` im  
Firestore-Dokument `users/{uid}.roles` (Array).  
Das lässt sich in der App unter **Benutzerverwaltung** einstellen.

### 3. Functions deployen

```bash
firebase deploy --only functions:scoreboardApi
```

### 4. Base URL in der Scoreboard-Software

```
https://us-central1-gbo-updated.cloudfunctions.net/scoreboardApi
```
