# Test Protocol – Roadmap Implementation & Dependency Fixes

> **Project:** GBO-Updated (Rollstuhlhandball Bundesliga)  
> **Date:** 2026-04-09  
> **Scope:** Phases A–H, earlier feature additions, dependency upgrade fixes  
> **Target:** Flutter Web (Chrome)

---

## How to Use This Document

- Work through each section in order
- Mark each test case with ✅ (pass), ❌ (fail), or ⏭️ (skipped / not applicable)
- Note any issues in the "Notes" column
- Prerequisites are listed per section

---

## 0. Build Verification

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 0.1 | Clean build | `flutter clean && flutter pub get && flutter run -d chrome` | App compiles and runs without errors | | |
| 0.2 | No console errors | Open DevTools console in Chrome | No red errors on startup | | |
| 0.3 | Login works | Enter valid credentials, click Login | Redirected to Home screen with correct role sections | pass | |

---

## 1. Phase A – Spielbericht PDF Export

**File:** `lib/services/spielbericht_pdf_service.dart`, `lib/screens/game_report_screen.dart`  
**Prereq:** A locked/completed game must exist in a tournament


**ISSUE** - Turnierverwaltung -> Tournament -> Spiele -> Alle Spiele anzeigen does not show any games. it logs them but does not show them.

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 1.1 | PDF button visible | Navigate to a **locked** game → Game Report | "PDF exportieren" button is visible | pass | |
| 1.2 | PDF button hidden for unlocked games | Navigate to an **unlocked** game → Game Report | No PDF export button | pass | |
| 1.3 | PDF generation | Click "PDF exportieren" | PDF is generated and browser download/share dialog opens | pass | |
| 1.4 | PDF content | Open the downloaded PDF | Contains: header with teams, score, squad tables, game events, statistics, signature area | pass | |
| 1.5 | PDF format | Check the PDF layout | A4 landscape/portrait, readable fonts, proper table alignment | pass - change request | pdf should not just show team statistics but also roster with each statistics. also I want to see the referees and delegate |

---

## 2. Phase B – Public Scoreboard

**File:** `lib/screens/public_scoreboard_screen.dart`, `firestore.rules`  
**Prereq:** At least one tournament with games must exist  
**Route:** `/public?t={tournamentId}`

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 2.1 | Access without login | Open `/public?t={id}` in incognito browser | Scoreboard loads without requiring login | pass | |
| 2.2 | Missing tournament ID | Open `/public` (no `?t=` param) | Error message displayed ("Turnier nicht gefunden" or similar) | pass | also if possible dont make me do /#/public |
| 2.3 | Live tab | Click "Live" tab | Shows current/recent live games with scores | skip | 2.1/2.2 not working |
| 2.4 | Tabelle tab | Click "Tabelle" tab | Shows team standings table | skip | 2.1/2.2 not working |
| 2.5 | Torjäger tab | Click "Torjäger" tab | Shows top scorers list | skip | 2.1/2.2 not working |
| 2.6 | Real-time updates | Change a game score in another session | Live tab updates without page refresh | skip | 2.1/2.2 not working |
| 2.7 | Firestore rules | Attempt to write to `tournaments` from unauthenticated client | Write should be **denied** | skip | 2.1/2.2 not working |

---

## 3. Phase C – Kiosk Mode

**File:** `lib/screens/kiosk_screen.dart`  
**Prereq:** Tournament with live/upcoming/completed games  
**Route:** `/kiosk?t={tournamentId}`

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 3.1 | Access without login | Open `/kiosk?t={id}` in incognito browser | Kiosk loads without login | fail | just shows normal landing page (turniere tab) |
| 3.2 | Dark theme | Observe UI | Dark background, large readable fonts | skip | 3.1 not working |
| 3.3 | Auto-rotation | Wait 60+ seconds | View cycles through: Live → Upcoming → Standings → Results (every ~15s) | skip | 3.1 not working |
| 3.4 | View indicators | Look at bottom of screen | Dot indicators show which view is active | skip | 3.1 not working |
| 3.5 | Auto-refresh | Wait 30+ seconds in one view | Data refreshes automatically (check console for refresh logs) | skip | 3.1 not working |
| 3.6 | Missing tournament | Open `/kiosk` without `?t=` | Error message: "Keine Turnier-ID" | pass | also if possible dont make me do /#/kiosk |
| 3.7 | Full-screen suitability | Open on a large display | No scroll bars, content fills screen, suitable for venue TV | skip | 3.1 not working |

---

## 4. Phase D – FCM Web Push

**File:** `lib/services/fcm_service.dart`, `web/firebase-messaging-sw.js`, `web/index.html`  
**Prereq:** Logged-in user, browser notifications enabled

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 4.1 | Permission prompt | Login for the first time (or clear notification settings) | Browser shows "Allow notifications?" prompt | fail | no prompt |
| 4.2 | Permission granted | Click "Allow" on the prompt | Console logs "FCM token saved" or similar | skip | no prompt |
| 4.3 | Token stored | Check Firestore → `users/{uid}` | `fcmTokens` array contains the browser token | fail | no entry (may be due to 4.1 fail) |
| 4.4 | Service worker registration | Open DevTools → Application → Service Workers | `firebase-messaging-sw.js` is registered and active | skip | 4.1 |
| 4.5 | Background notification | Minimize/blur the tab, trigger a notification via Cloud Function or Firestore | Browser native notification appears with title and body | skip | 4.1 |
| 4.6 | Token refresh | Clear site data and re-login | New token is saved, old token replaced or added | skip | 4.1 |

---

## 5. Phase E – Expanded Push Notifications (Cloud Functions)

**File:** `functions/src/index.ts`  
**Prereq:** Cloud Functions deployed via `firebase deploy --only functions`, FCM token registered

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 5.1 | Game result notification | Complete/lock a game with a final score | Subscribed users receive push: "Ergebnis: {Team A} vs {Team B}: {score}" | | |
| 5.2 | Live score update | Update a running game's score in Firestore | Data-only message sent (no visible notification on web, but data arrives) | | |
| 5.3 | Protest notification | Create a new protest document in Firestore | Subscribed users receive push: "Protest eingereicht" with team/game info | | |
| 5.4 | Topic targeting | Check that notifications go to `tournament_{id}` topic | Only users subscribed to the specific tournament receive the notification | | |

> **Note:** Cloud Functions require `cd functions && npm install && firebase deploy --only functions` before testing.

---

## 6. Phase F – Official Communication (Broadcast)

**File:** `lib/services/custom_notification_service.dart`, `lib/screens/custom_notification_screen.dart`  
**Prereq:** Admin or Team-RHD role, multiple users with different roles/teams in system

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 6.1 | Screen access | Navigate to Notification screen (side nav) | Screen loads with recipient mode toggle | pass | |
| 6.2 | Mode: Einzeln | Select "Einzeln" mode | Shows email dropdown for single user selection | pass | |
| 6.3 | Mode: Alle | Select "Alle" mode | Shows info banner "Nachricht an alle Benutzer", no user selector | pass | |
| 6.4 | Mode: Rolle | Select "Rolle" mode | Shows role checkboxes (Admin, Trainer, Schiedsrichter, etc.) | pass | |
| 6.5 | Mode: Team | Select "Team" mode | Shows team checkboxes loaded from Firestore | pass | |
| 6.6 | Send broadcast (all) | Fill title + message, select "Alle", click Send | Toast: "Broadcast an X Empfänger gesendet", records created in Firestore | partial pass | defined working, entry is in firebase, further depending on 4.1|
| 6.7 | Send broadcast (role) | Select "Rolle", check "Trainer", fill title + message, send | Only users with Trainer role receive the notification | partial pass | defined working, entry is in firebase, further depending on 4.1 |
| 6.8 | Send broadcast (team) | Select "Team", check a specific team, send | Only users associated with that team receive the notification | partial pass | defined working, entry is in firebase, further depending on 4.1 |
| 6.9 | Preset templates | Click template presets (Spielverlegung, Absage) | Dialog opens with pre-filled title/message for the template | pass | |
| 6.10 | Single user notification | Select "Einzeln", pick a user, send | Notification sent to that one user only | pass | |
| 6.11 | Firestore records | Check `custom_notifications` collection after broadcast | Records have `type: 'broadcast'`, correct `filterRoles`/`filterTeamIds` | pass | |

---

## 7. Phase G – Document Management

**File:** `lib/models/document.dart`, `lib/services/document_service.dart`, `lib/screens/document_management_screen.dart`  
**Prereq:** Admin or commissioner role

**Fail** No further Testing after trying to upload an item. Error Message: This Query Requires an Index.

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 7.1 | Navigation | Click "Dokumente" in side nav (commissioner section) | Document Management screen opens | pass | |
| 7.2 | Category filters | Click each category chip (Alle, Spielordnung, Regularien, Satzung, Sonstiges) | Document list filters accordingly | | |
| 7.3 | Upload – file picker | Click upload button (FAB or action button) | File picker opens, shows only pdf/doc/docx/xlsx/xls files | | |
| 7.4 | Upload – dialog | Pick a file | Upload dialog appears with: document name field, category dropdown, file info | | |
| 7.5 | Upload – success | Fill name, select category, click "Hochladen" | File uploads to Firebase Storage, success toast shown, document appears in list | | |
| 7.6 | Upload – cancel | Click "Abbrechen" in upload dialog | Nothing uploaded, dialog closes | | |
| 7.7 | Document card info | Look at a document in the list | Shows: name, category, file size, version, upload date | | |
| 7.8 | Open document | Click open/download on a document | Document opens in new browser tab or downloads | | |
| 7.9 | Delete document | Click delete on a document, confirm | Document removed from list and Firestore, file deleted from Storage | | |
| 7.10 | Version tracking | Upload a document with the same name as an existing one | Version number auto-increments (v2, v3, etc.) | | |
| 7.11 | Empty state | Filter to a category with no documents | Appropriate "no documents" message shown | | |

---

## 8. Phase H – Offline Resilience

**File:** `lib/main.dart`, `lib/widgets/offline_banner.dart`  
**Prereq:** App running in Chrome

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 8.1 | Firestore persistence | Open DevTools → Application → IndexedDB | `firebaseLocalStorageDb` or Firestore persistence DB exists | pass | |
| 8.2 | Offline banner appears | Disable network (DevTools → Network → Offline) | Red banner appears: "Keine Internetverbindung – Offline-Modus aktiv" with wifi_off icon | pass | |
| 8.3 | Banner animation | Toggle network off/on | Banner slides in/out smoothly (AnimatedSwitcher) | pass | |
| 8.4 | Online – banner hidden | Re-enable network | Red banner disappears | pass | |
| 8.5 | Cached data available | Go offline → navigate to a previously loaded screen | Data still renders from Firestore cache | pass | |
| 8.6 | Write queuing | Go offline → create/edit something → go back online | Change persists and syncs when connection returns | pass | may need exception rule for city in the tournament creation |

---

## 9. Earlier Features (Prior Session)

### 9a. Venue Management

**File:** `lib/screens/venue_management_screen.dart`

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 9a.1 | Screen loads | Navigate to Venue Management | List of venues displayed | pass | |
| 9a.2 | Search | Type in search bar | Venues filter by name/city/street | pass | |
| 9a.3 | Add venue | Click add, fill form, save | New venue appears in list | pass | |
| 9a.4 | Edit venue | Click edit on existing venue | Form pre-filled, save updates venue | pass | |
| 9a.5 | Delete venue | Click delete, confirm | Venue removed from list | pass | |

### 9b. Player Transfers

**File:** `lib/screens/player_transfer_screen.dart`

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 9b.1 | Screen loads | Navigate to Player Transfers | Transfer list displayed | pass | |
| 9b.2 | Status filter | Toggle Alle/Offen/Genehmigt | Lists filters by transfer status | pass | |
| 9b.3 | Request transfer | Click "Transfer anfragen" | Dialog opens with team dropdowns and player selection | pass | |
| 9b.4 | Team selection loads players | Select a "from" team | Player list populates for that team | pass | |
| 9b.5 | Submit transfer | Fill all fields, submit | Transfer request created, appears in list | pass | |
| 9b.6 | Approve/reject | Click approve or reject on a pending transfer | Status updates accordingly | pass | |

### 9c. Season Management

**File:** `lib/screens/season_management_screen.dart`

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 9c.1 | Screen loads | Navigate to Season Management | Season list displayed | pass | |
| 9c.2 | Create season | Click create, fill form, save | New season appears | pass | |
| 9c.3 | Activate season | Click activate on a season | Season marked as active, others deactivated | pass | |
| 9c.4 | Tournaments per season | Select a season | Related tournaments shown | pass | |

__comments:__ maybe make the "Rangliste" and "Turniere" pages refer to those seasons

---

## 10. Dependency Upgrade Fixes

**Upgraded packages:** `file_picker ^11`, `flutter_local_notifications ^20`, `local_auth ^3`, `firebase_storage ^13`, `firebase_messaging ^16`, `connectivity_plus ^7`, `flutter_secure_storage ^10`, `package_info_plus ^9`, `flutter_lints ^6`

### 10a. file_picker v11 (static methods)

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 10a.1 | Player CSV import | Player Management → CSV Upload → pick CSV file | File picker opens, file loads correctly | pass | |
| 10a.2 | City migration CSV | City Migration → Import CSV → pick CSV file | File loads, migration preview shown | pass | |
| 10a.3 | Document upload | Document Management → Upload → pick file | File picker opens with correct extension filter | pass | |

### 10b. flutter_local_notifications v20 (named params)

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 10b.1 | Notification service init | App starts without crash | Console shows "Local notifications initialized" | pass | |
| 10b.2 | Show notification | Trigger a custom notification (send one to yourself) | Local notification renders correctly | skip | 4.1 |
| 10b.3 | Coach auth notification | Trigger a coach auth request | Notification shown with title, body, and payload | skip | 4.1 |
| 10b.4 | Notification tap | Tap on a notification | Correct navigation/action occurs | skip | 4.1 |

### 10c. local_auth v3 (removed AuthenticationOptions)

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 10c.1 | Biometric login | Try biometric login (iOS/Android only) | Authentication prompt appears, returns result | skip | currently web testing |
| 10c.2 | Admin biometric auth | Try admin area biometric (iOS/Android only) | Authentication prompt appears, returns result | skip | currently web testing |

> **Note:** local_auth is not functional in Chrome/web. Tests 10c.1–10c.2 only apply to iOS/Android builds.

### 10d. Other fixes

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 10d.1 | Tournament.fromMap | Open Public Scoreboard (`/public?t={id}`) | Tournament data loads without "fromJson" error | skip | 2.1 |
| 10d.2 | Tournament.fromMap (kiosk) | Open Kiosk (`/kiosk?t={id}`) | Tournament data loads without error | skip | 3.1 |
| 10d.3 | Protest list (commissioner) | Navigate to Protest List from commissioner section | Screen opens without crash (shows empty list if no tournamentId) | fail | requires an inde |
| 10d.4 | Player transfer dialog | Open transfer dialog | Player list loads via `.first` on stream without type error | pass | |
| 10d.5 | Document upload user ID | Upload a document | `uploadedByUserId` populated correctly (not "unknown") when logged in | skip | |
| 10d.6 | Navigator key | Tap on a push notification that navigates to a screen | Navigation works correctly via `RHBLApp.navigatorKey` | skip | |
| 10d.7 | Connectivity import | Toggle network on/off | Offline banner works without `connectivity_plus` import errors | pass | |

---

## 11. Cross-Cutting Concerns

| # | Test | Steps | Expected | Status | Notes |
|---|------|-------|----------|--------|-------|
| 11.1 | Responsive layout | Resize browser to mobile/tablet/desktop widths | All new screens adapt layout properly | pass | |
| 11.2 | German locale | Check all new UI text | All labels, buttons, messages in German | pass | |
| 11.3 | Role-based access | Login with different roles (Admin, Trainer, Schiedsrichter, Spieler) | Only see permitted navigation items and screens | pass | |
| 11.4 | No console errors | Navigate through all new screens | No uncaught exceptions or red errors in console | fail-ish | Unable to find a font to draw "–" (U+2013) try to provide a TextStyle.fontFallback // some symbols like Ü Ä Ö ß and so on dont show correctly |
| 11.5 | Hot reload stability | Change code, hot reload | App doesn't crash on hot reload | pass | |

---

## Summary

| Phase | Test Cases | Priority |
|-------|-----------|----------|
| 0 – Build | 3 | 🔴 Critical |
| A – PDF Export | 5 | 🟡 Medium |
| B – Public Scoreboard | 7 | 🟡 Medium |
| C – Kiosk Mode | 7 | 🟡 Medium |
| D – FCM Web Push | 6 | 🟠 High |
| E – Cloud Functions | 4 | 🟠 High |
| F – Broadcast | 11 | 🟠 High |
| G – Document Management | 11 | 🟠 High |
| H – Offline Resilience | 6 | 🟡 Medium |
| 9 – Earlier Features | 15 | 🟡 Medium |
| 10 – Dependency Fixes | 14 | 🔴 Critical |
| 11 – Cross-Cutting | 5 | 🟡 Medium |
| **Total** | **94** | |

---

## Quick Smoke Test (Top 10)

If you only have limited time, run these first:

1. **0.1** – App compiles and runs (`flutter run -d chrome`)
2. **10a.3** – Document upload file picker works (file_picker v11)
3. **10d.1** – Public scoreboard loads (Tournament.fromMap)
4. **2.1** – Public scoreboard accessible without login
5. **3.3** – Kiosk auto-rotation works
6. **6.2–6.5** – Broadcast recipient modes render correctly
7. **7.3–7.5** – Document upload flow works end-to-end
8. **8.2** – Offline banner appears when network is disabled
9. **9b.3** – Player transfer dialog opens and loads players
10. **10d.3** – Protest list opens from commissioner section without crash
