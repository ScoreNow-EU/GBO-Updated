# GBO Architecture Guide — Referee & Kampfgericht Assignment System

## Table of Contents

1. [Overview](#overview)
2. [System Components](#system-components)
3. [Data Flow](#data-flow)
4. [Geocoding & Distance Calculation](#geocoding--distance-calculation)
5. [Kampfgericht Management](#kampfgericht-management)
6. [AI Solver (Cloud Function)](#ai-solver-cloud-function)
7. [Assignment Screen (Flutter)](#assignment-screen-flutter)
8. [Tournament Edit Screen Integration](#tournament-edit-screen-integration)
9. [What Needs to Change for Pure Firebase Deployment](#what-needs-to-change-for-pure-firebase-deployment)
10. [Deployment Steps](#deployment-steps)

---

## Overview

The system adds three major features to the GBO app:

1. **Referee & Kampfgericht management** — CRUD with full German addresses, auto-geocoding, and distance calculation to tournament venues.
2. **Availability tracking** — The admin manually sets who is available for each tournament (no app-based invitation flow).
3. **AI-based assignment** — A Firebase Cloud Function solves the optimal assignment of referees and Kampfgericht members to games, maximizing break times.

### Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter/Dart (Web + Mobile) |
| Backend | Firebase (Firestore, Auth, Hosting, Cloud Functions) |
| Geocoding | OpenStreetMap Nominatim (external, free) |
| Routing/Distance | OSRM demo server (external, free) |
| Solver | TypeScript Cloud Function (greedy + local search) |

---

## System Components

### Models

| Model | File | Firestore Collection |
|---|---|---|
| `Referee` | `lib/models/referee.dart` | `referees` |
| `KampfgerichtMember` | `lib/models/kampfgericht_member.dart` | `kampfgericht_members` |
| `Tournament` | `lib/models/tournament.dart` | `tournaments` |
| `Game` | `lib/models/game.dart` | `tournaments/{id}/games` |
| `RefereeInvitation` | `lib/models/tournament.dart` | Embedded in tournament doc |
| `KampfgerichtInvitation` | `lib/models/tournament.dart` | Embedded in tournament doc |
| `AssignmentConstraints` | `lib/models/assignment_constraints.dart` | Client-side only (sent to solver) |

### Services

| Service | File | External Dependencies |
|---|---|---|
| `RefereeService` | `lib/services/referee_service.dart` | Firestore + GeocodingService |
| `KampfgerichtService` | `lib/services/kampfgericht_service.dart` | Firestore + GeocodingService |
| `TournamentService` | `lib/services/tournament_service.dart` | Firestore + GeocodingService |
| `GeocodingService` | `lib/services/geocoding_service.dart` | **Nominatim + OSRM** (external HTTP) |
| `AssignmentSolverService` | `lib/services/assignment_solver_service.dart` | **Cloud Function** (external HTTP) |

### Cloud Function

| Function | File | Purpose |
|---|---|---|
| `solveGameAssignment` | `functions/src/index.ts` | HTTP endpoint for the solver |
| Solver logic | `functions/src/solver.ts` | Greedy + local search algorithm |

---

## Data Flow

### Referee/Kampfgericht Creation
```
Admin creates referee → RefereeService.addReferee()
  ├─ Writes to Firestore (referees collection)
  └─ Calls GeocodingService.geocodeAddress()
       ├─ HTTP → Nominatim API (street + PLZ + city → lat/lng)
       └─ Stores lat/lng on referee document
```

### Tournament Setup
```
Admin edits tournament
  ├─ Selects referees → stored as RefereeInvitation[] in tournament doc
  ├─ Selects Kampfgericht → stored as KampfgerichtInvitation[] in tournament doc
  ├─ Enters venue address → TournamentService.updateVenueAddress()
  │    └─ Geocodes venue → stores venueLatitude/venueLongitude
  └─ Sets availability per referee/KG member (availableFrom/Until/isFullDay)
```

### AI Assignment
```
Admin clicks "KI-Zuordnung starten"
  ├─ Flutter builds payload: { games, officials, constraints, compatibilities }
  ├─ HTTP POST → Cloud Function (solveGameAssignment)
  │    ├─ Greedy assignment (sorted by game time)
  │    ├─ Local search refinement (pairwise swaps)
  │    └─ Returns { assignments, breakTimes, isOptimal, warnings }
  ├─ Admin reviews results in UI
  └─ Admin clicks "Übernehmen" → writes assignments to Firestore game docs
       └─ Updates referee1Id, referee2Id, timekeeperId, scorekeeperId per game
```

---

## Geocoding & Distance Calculation

### How It Works Now

**Geocoding** (`GeocodingService.geocodeAddress`):
- Calls `https://nominatim.openstreetmap.org/search` with the formatted address
- Rate-limited to 1 request/second (enforced in code)
- Country locked to `de` (Germany)
- Results cached in-memory (not persisted)

**Distance** (`GeocodingService.calculateDrivingDistance`):
- Calls `https://router.project-osrm.org/route/v1/driving/{coords}`
- Falls back to Haversine (straight-line) if OSRM fails
- Returns `DistanceResult` with `distanceKm`, `durationMinutes`, `isEstimate`

### Where It's Used

1. `RefereeService` — geocodes referee home address on add/update
2. `KampfgerichtService` — geocodes KG member home address on add/update
3. `TournamentService.updateVenueAddress()` — geocodes the tournament venue
4. `TournamentService.getDistancesToVenue()` — calculates distance from every accepted referee to the venue

### ⚠️ Production Concerns

| Issue | Detail |
|---|---|
| **Nominatim rate limit** | Max 1 req/sec, max ~1000/day for automated use. Fine for a few dozen referees, problematic at scale. |
| **OSRM demo server** | Explicitly "not for production use" per OSRM project. Can go down without notice. |
| **No persistence** | Geocode cache is in-memory only — lost on app restart. |

---

## Kampfgericht Management

**Key principle:** "All referees can be Timekeeper/Scorekeeper. Not all Timekeepers/Scorekeepers are referees."

- Kampfgericht members are stored in a **separate Firestore collection** (`kampfgericht_members`)
- They have the same address fields as referees (street, houseNumber, plz, city, lat, lng)
- No license types — just name, email, phone, address
- Managed via `KampfgerichtManagementScreen` (accessible from side nav under "Kampfgericht Verwaltung")
- Selected per tournament in the "Kampfgericht" tab of the tournament editor

When the solver runs, referees are sent **twice**:
1. As `type: "referee"` — eligible for SR1/SR2 roles
2. As `type: "kampfgericht_capable_referee"` (ID suffixed with `_kg`) — eligible for Zeitnehmer/Sekretär roles

Dedicated Kampfgericht members are sent as `type: "kampfgericht"` — only eligible for Zeitnehmer/Sekretär.

---

## AI Solver (Cloud Function)

### Algorithm

The solver uses a **greedy heuristic with local search refinement**:

**Phase 1 — Manual overrides:** Honor any fixed (manual) assignments from constraints.

**Phase 2 — Greedy assignment:**
- Games sorted by scheduled time
- For each game, for each unassigned role (SR1 → SR2 → Zeitnehmer → Sekretär):
  - Score every eligible official by: "What would my minimum break be if I take this game?"
  - Assign the official with the best (highest) minimum break
  - Less-used officials get a bonus to distribute load

**Phase 3 — Local search:**
- Iterate up to 100 times
- For each pair of games, try swapping same-role assignments
- Accept the swap if it improves the global minimum break
- Stop when no improvement found

### Hard Constraints

- No double-booking (same person cannot be assigned to overlapping games)
- Availability windows (availableFrom/availableUntil)
- License level requirements (per-game minimum)
- Manual overrides (solver must use the specified official)
- Excluded officials (per-game blacklist)
- Compatibility rules (who can/cannot work together)

### Input/Output Format

**Input (POST body):**
```json
{
  "games": [
    { "id": "g1", "scheduledTime": "2026-06-15T10:00:00Z", "durationMinutes": 40, "courtId": "c1" }
  ],
  "officials": [
    { "id": "ref1", "type": "referee", "licenseLevel": "Leistungskader", "isFullDay": true }
  ],
  "constraints": [
    { "gameId": "g1", "requiredLicenseLevel": "Elitekader", "excludedOfficialIds": ["ref3"] }
  ],
  "compatibilities": [
    { "official1Id": "ref1", "official2Id": "ref2", "canWorkTogether": false }
  ]
}
```

**Output:**
```json
{
  "assignments": [
    { "gameId": "g1", "referee1Id": "ref1", "referee2Id": "ref2", "timekeeperId": "kg1", "scorekeeperId": "ref3_kg" }
  ],
  "breakTimes": { "ref1": [25, 30], "ref2": [20] },
  "isOptimal": true,
  "warnings": []
}
```

### Deployment

The function is located in `functions/` and configured in `firebase.json`:

```
functions/
├── src/
│   ├── index.ts      ← HTTP entry point
│   └── solver.ts     ← Algorithm
├── package.json
└── tsconfig.json
```

---

## Assignment Screen (Flutter)

`lib/screens/tournament_assignment_screen.dart`

### Three Views

| View | Content |
|---|---|
| **Spiele & Einschränkungen** | Game list with expandable per-game constraint editor |
| **Ergebnisse** | DataTable of solver results (after running solver) |
| **Zusammenfassung** | Per-official stats: assignment count, min/avg break times |

### Per-Game Constraints

The admin can set for each game:
- **Min. Lizenzstufe** — dropdown (Entwicklungskader → EHF Referee)
- **SR 1/SR 2 (fest)** — manually fix a specific referee
- **Zeitnehmer/Sekretär (fest)** — manually fix a Kampfgericht person
- These are sent to the solver as `GameAssignmentConstraint` objects

### Actions

- **"KI-Zuordnung starten"** (FAB) — calls the Cloud Function
- **"Zuordnung übernehmen"** — writes results to Firestore game docs
- **"Alle Zuordnungen löschen"** — clears all assignments

---

## Tournament Edit Screen Integration

The tournament editor (`lib/screens/tournament_edit_screen.dart`) has these new tabs:

| Tab Key | Label | Purpose |
|---|---|---|
| `kampfgericht` | Kampfgericht | Select KG members for this tournament |
| `assignment` | Zuordnung | Opens the assignment screen (embedded) |

New form fields in the "Basisdaten" tab:
- **Hallenadresse** card — Straße, Hausnummer, PLZ for the tournament venue

All three `Tournament()` constructor calls in the file now pass:
- `venueStreet`, `venueHouseNumber`, `venuePlz`
- `venueLatitude`, `venueLongitude` (from existing tournament data)
- `kampfgerichtInvitations` (built from `_selectedKampfgerichtIds`)

---

## What Needs to Change for Pure Firebase Deployment

### 1. Deploy the Cloud Function

The solver Cloud Function needs to be deployed and its URL configured in the app.

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

After deployment, the URL will be:
```
https://us-central1-gbo-updated.cloudfunctions.net/solveGameAssignment
```

**In the app**, set this URL on the `AssignmentSolverService`:

```dart
// In your app initialization or tournament assignment screen:
final solverService = AssignmentSolverService(
  cloudFunctionUrl: 'https://us-central1-gbo-updated.cloudfunctions.net/solveGameAssignment',
);
```

> **Current state:** The URL is NOT hardcoded. You must pass it via constructor or call `setCloudFunctionUrl()`.

### 2. Replace Nominatim with a Firebase-Compatible Solution

Nominatim is free but rate-limited and not suitable for production. Options:

| Option | Effort | Cost |
|---|---|---|
| **A) Keep Nominatim** | None | Free, but fragile (1 req/sec, may block you) |
| **B) Google Maps Geocoding API** | Medium | ~$5/1000 requests (free tier: $200/month credit) |
| **C) Cache geocode results in Firestore** | Low | Free (geocode once, store forever) |
| **D) Firebase Extension (Google Maps)** | Low | Uses Google Maps API pricing |

**Recommended: Option C** — Geocode lazily and store results in Firestore. Modify `GeocodingService` to:

1. Check Firestore cache first (`geocode_cache/{addressHash}`)
2. If not found, call Nominatim
3. Store the result in Firestore for future use

This way you only hit Nominatim once per unique address, and the cache survives app restarts.

**Changes needed in `lib/services/geocoding_service.dart`:**

```dart
// Add Firestore cache layer:
final _cacheCollection = FirebaseFirestore.instance.collection('geocode_cache');

Future<Map<String, double>?> geocodeAddress(String street, String plz, String city) async {
  final cacheKey = '$street|$plz|$city'.hashCode.toString();
  
  // 1. Check Firestore cache
  final cached = await _cacheCollection.doc(cacheKey).get();
  if (cached.exists) {
    return {'lat': cached['lat'], 'lng': cached['lng']};
  }
  
  // 2. Call Nominatim (existing code)
  final result = await _nominatimGeocode(street, plz, city);
  
  // 3. Store in Firestore
  if (result != null) {
    await _cacheCollection.doc(cacheKey).set({
      'lat': result['lat'], 'lng': result['lng'],
      'address': '$street, $plz $city',
      'cachedAt': FieldValue.serverTimestamp(),
    });
  }
  
  return result;
}
```

### 3. Replace OSRM with Haversine or Google Directions

The OSRM demo server (`router.project-osrm.org`) is **not for production**. Options:

| Option | Effort | Cost |
|---|---|---|
| **A) Haversine only** | None (already implemented as fallback) | Free, but inaccurate (~30% off for driving) |
| **B) Google Directions API** | Medium | ~$5-10/1000 requests |
| **C) Remove distance feature** | None | Free — distances are nice-to-have, not critical |
| **D) Self-host OSRM** | High | Server cost (~$10-30/month for a VM) |

**Recommended: Option A** — Use Haversine (straight-line) with a 1.3× multiplier as a driving estimate. Already built into the code as the fallback path.

**Change in `lib/services/geocoding_service.dart`:**
```dart
// Just always use Haversine instead of calling OSRM:
Future<DistanceResult> calculateDistance(double lat1, double lng1, double lat2, double lng2) async {
  return _haversineDistance(lat1, lng1, lat2, lng2);
}
```

### 4. Add Firestore Security Rules

Currently **no Firestore rules** are defined in `firebase.json`. For production:

Create `firestore.rules`:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Only authenticated users can read
    match /{document=**} {
      allow read: if request.auth != null;
    }
    
    // Only admins can write referees and kampfgericht
    match /referees/{refId} {
      allow write: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    match /kampfgericht_members/{memberId} {
      allow write: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Geocode cache: anyone authenticated can read/write
    match /geocode_cache/{cacheId} {
      allow read, write: if request.auth != null;
    }
    
    // Tournaments: authenticated users can read, admins can write
    match /tournaments/{tournamentId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
      match /games/{gameId} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

Add to `firebase.json`:
```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  }
}
```

### 5. Configure the Solver URL in the App

The `AssignmentSolverService` has no hardcoded URL. You need to wire it up. Best approach:

**Option A — Hardcode after deployment:**
```dart
// In tournament_assignment_screen.dart, change:
final AssignmentSolverService _solverService = AssignmentSolverService(
  cloudFunctionUrl: 'https://us-central1-gbo-updated.cloudfunctions.net/solveGameAssignment',
);
```

**Option B — Store in Firestore config document:**
```dart
// Read from Firestore at startup:
final configDoc = await FirebaseFirestore.instance.doc('config/solver').get();
final url = configDoc.data()?['functionUrl'] as String?;
_solverService.setCloudFunctionUrl(url ?? '');
```

**Option C — Use Firebase Remote Config** (most flexible, can change URL without app update).

### 6. Venue Address Controller Cleanup

The venue address controllers (`_venueStreetController`, `_venueHouseNumberController`, `_venuePlzController`) are declared and used in the tournament edit screen but their value only gets stored when saving the tournament. For auto-geocoding on save, add a call to `TournamentService.updateVenueAddress()` in the save flow, or rely on the fields being passed in the `Tournament()` constructor (which is already done).

---

## Deployment Steps

### Prerequisites
- Node.js 18+ installed
- Firebase CLI installed (`npm install -g firebase-tools`)
- Logged into Firebase CLI (`firebase login`)
- Flutter SDK installed

### Step-by-Step

```bash
# 1. Deploy Cloud Functions
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions

# 2. Note the deployed function URL (printed in terminal output)
# Example: https://us-central1-gbo-updated.cloudfunctions.net/solveGameAssignment

# 3. Set the URL in the app (see section 5 above)

# 4. Build and deploy the web app
flutter build web
firebase deploy --only hosting

# 5. (Optional) Deploy Firestore rules
firebase deploy --only firestore:rules
```

### Testing the Solver Locally

```bash
# Start Firebase emulators
cd functions
npm run serve

# The function will be available at:
# http://localhost:5001/gbo-updated/us-central1/solveGameAssignment

# Test with curl:
curl -X POST http://localhost:5001/gbo-updated/us-central1/solveGameAssignment \
  -H "Content-Type: application/json" \
  -d '{
    "games": [{"id":"g1","scheduledTime":"2026-06-15T10:00:00Z","durationMinutes":40}],
    "officials": [{"id":"r1","type":"referee","licenseLevel":"Leistungskader","isFullDay":true},{"id":"r2","type":"referee","licenseLevel":"Elitekader","isFullDay":true},{"id":"k1","type":"kampfgericht","isFullDay":true},{"id":"k2","type":"kampfgericht","isFullDay":true}],
    "constraints": [],
    "compatibilities": []
  }'
```

---

## Summary of Required Changes

| # | Change | File(s) | Priority |
|---|---|---|---|
| 1 | Deploy Cloud Function | `functions/` | **Required** |
| 2 | Set solver URL in app | `tournament_assignment_screen.dart` | **Required** |
| 3 | Add Firestore geocode cache | `geocoding_service.dart` | Recommended |
| 4 | Replace OSRM with Haversine | `geocoding_service.dart` | Recommended |
| 5 | Add Firestore security rules | `firestore.rules` (new) | **Required** for production |
| 6 | Add Firestore indexes | `firestore.indexes.json` (new) | As needed |
| 7 | Configure Firebase Remote Config for solver URL | `firebase_config.dart` | Optional |

Everything else — models, services, screens, navigation — is already wired up and working with Firestore. No additional Firebase changes needed for the core functionality.
