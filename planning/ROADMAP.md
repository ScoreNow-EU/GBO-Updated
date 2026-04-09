# GBO App — Complete Roadmap for RHD Production

> Full nuLiga replacement for Rollstuhlhandball Deutschland (RHD).
> Web PWA primary, single app with role-based views.

---

## Phase 1: Core Model & Role Additions (Foundation) — ✅ COMPLETE

*Unblocks most other phases. Do first.*

| # | Item | Description |
|---|------|-------------|
| 1.1 | ✅ **Add `teamRHD` role** | League commissioner role in `UserRole` enum. Below admin, can set penalties, manage suspensions, is "leitende Stelle". Update role management screen + Firestore rules. |
| 1.2 | ✅ **Add `spielerpassNummer` to Player** | Digital license number field. Update edit forms, bulk import, squad display. |
| 1.3 | ✅ **Create Protest model + service** | Fields: id, gameId, tournamentId, filedBy, reason, status (filed/reviewed/accepted/rejected), resolution, notifiedRoles. |
| 1.4 | ✅ **Create Suspension model + service** | Cross-tournament bans by teamRHD. Extend `disciplinary_service.dart`. Blue card = tournament ban, teamRHD can enter season-wide bans. |
| 1.5 | ✅ **Create Season model + service** | Spieltage = tournament IDs, format (round-robin/swiss/groups), hosting teams, isActive. |
| 1.6 | ✅ **Create Venue model + service** | Hallenbörse directory. Name, address, courts, capacity, host team. Reusable across tournaments. |
| 1.7 | ✅ **Create Fine model + service** | Strafen/Bußgelder issued by teamRHD. Amount, reason, payment status, linked to infractions. |

---

## Phase 2: Tournament Day Workflow Completion — ✅ COMPLETE

*The "no more paper" phase.*

| # | Item | Description |
|---|------|-------------|
| 2.1 | ✅ **Digital Spielbericht with Signatures** | Enhance `game_report_screen.dart`: referee/coach/delegate sign-off (biometric or slider). Add PDF export. Protest indicator. Signature fields in Game/gameStates. |
| 2.2 | ✅ **Spielerpass-Kontrolle** | New screen: delegate views squad + Spielerpass-Nr + classification. Verify button per player. Protest button. QR scan for physical pass in case of doubt. |
| 2.3 | ✅ **Protest Workflow** | Coach files protest before signing Spielbericht → all parties notified (refs, delegate, Zeitnehmer/Sekretär, opposing coach, teamRHD, tournament organizer) → resolution documented. |
| 2.4 | ✅ **Blue Card Enforcement** | Add suspension check in `game_squad_service.dart` before squad submission. Block suspended players with visual indicator (red badge). |
| 2.5 | ✅ **Complete Sign-Off Chain** | Team A coach → Team B coach → Referee(s) → Delegate. Each timestamped. Game locked after all signatures. Notification sent to next signer. |
| 2.6 | ✅ **Manual Game Scheduling** | Admin can create individual games with custom team matchups, times, courts. Enables externally-generated Swiss system brackets to be entered by hand. |

---

## Phase 3: Role-Specific Views & Self-Service — ✅ COMPLETE

*Every role gets a personalized dashboard.*

| # | Item | Description |
|---|------|-------------|
| 3.1 | ✅ **Referee Dashboard** | My Games Today, My Availability (per-tournament), Decline Assignment (admin notified), calendar view. |
| 3.2 | ✅ **Player Dashboard** | My Team, My Schedule, My Spielerpass (QR code), Live Scores, standings. |
| 3.3 | ✅ **Team Manager Enhanced View** | My Tournament Schedule, Upcoming Squad Selection, Sign-Off Pending, Notification inbox. |
| 3.4 | ✅ **Delegate Dashboard** | All Games Today, Spielerpass Check, Protests, Discipline Overview, Spielberichte sign-off status. |
| 3.5 | ✅ **teamRHD Commissioner Dashboard** | Season Overview, Suspensions, Fines, Protests, Transfers, Documents, All Tournaments oversight. |

---

## Phase 4: Public Access & Kiosk Mode — ✅ COMPLETE

*No-login spectator experience + venue TV display.*

| # | Item | Description |
|---|------|-------------|
| 4.1 | ✅ **Public Scoreboard Page** | No login required. `/public/{tournamentId}`. Live scores, schedule, standings, top scorers. Real-time Firestore streams. Shareable QR code. |
| 4.2 | ✅ **Kiosk Mode for Venue TV** | `/kiosk/{tournamentId}`. Auto-rotate: live games → upcoming → standings → recent results. Full-screen, large fonts, no interaction needed. |
| 4.3 | ✅ **Live Score Notifications** | FCM topics per tournament. Subscribe from public page. Goals, game start/end, final results. |
| 4.4 | ✅ **Anonymous Firestore Rules** | Allow anonymous read on public tournament data (no PII — no emails, phones, addresses). |

---

## Phase 5: League Management (nuLiga Replacement) — ✅ COMPLETE

*Full season and league operations.*

| # | Item | Description |
|---|------|-------------|
| 5.1 | ✅ **Season Management** | Create/edit seasons, assign Spieltage (each team hosts one), set format, hosting teams. |
| 5.2 | ✅ **Player Transfers** | Team manager requests → teamRHD approves → player moved between rosters. Transfer history tracked. |
| 5.3 | ✅ **Team Registration for Season** | Season-wide registration, deadline, fee tracking via Fine system. |
| 5.4 | ✅ **Venue Management (Hallenbörse)** | Shared venue directory, link to tournaments, host team auto-assigned. |
| 5.5 | ✅ **Official Communication** | Spielverlegungen, Absagen, teamRHD announcements → mass notifications. |
| 5.6 | ✅ **Document Management** | Upload Spielordnung/Regularien/Satzung. Version tracking. Firebase Storage. PDF viewer in-app. |
| 5.7 | ✅ **Fine & Penalty Management** | teamRHD issues fines to teams/players. Track payment. Link to infractions. |

---

## Phase 6: Technical Foundation & Polish — ✅ COMPLETE

| # | Item | Description |
|---|------|-------------|
| 6.1 | ✅ **Offline Resilience** | `connectivity_plus` package. Offline indicator banner. Verify scoring survives brief drops. |
| 6.2 | ✅ **Expanded Push Notifications** | 7 auto-triggers: game starting soon, score updates, squad approval (✅), assignment published, schedule changes, protest filed, results final. |
| 6.3 | ✅ **Spielbericht PDF Export** | `pdf` + `printing` packages. Official format. Bulk export as ZIP. |
| 6.4 | ✅ **Firestore Rules Update** | New collections, anonymous read for public data, teamRHD permissions. |
| 6.5 | ✅ **Deploy Cloud Function** | Solver for AI referee assignment (`functions/src/solver.ts`). |
| 6.6 | ✅ **QR Code Integration** | `qr_flutter` (generate) + `mobile_scanner` (scan). Spielerpass, public URLs. |
| 6.7 | ✅ **FCM Web Push Setup** | Firebase Cloud Messaging certificates, service worker config for web push to spectators. |

---

## Decisions

| Decision | Choice |
|----------|--------|
| Primary platform | Web PWA |
| App architecture | Single app, role-based views |
| Public pages | No login required, anonymous Firestore read (no PII) |
| Offline strategy | Firestore cache + connectivity indicator (no Hive/SQLite) |
| Spielbericht | PDF replaces paper form |
| teamRHD role | Below admin, above all other roles. League commissioner / "leitende Stelle" |
| Blue card | Tournament ban (already implemented) |
| Red card | Current game disqualification only (no follow-up ban) |
| Cross-tournament suspensions | Entered by teamRHD only |
| Game formats | Round-robin + knockout for v1. Manual game scheduling for Swiss system compatibility |
| nuLiga migration | Manual data entry (no export from nuLiga) |
| FCM web push | In scope now |

---

## Role Hierarchy

```
admin (Developer/System Admin)
  └── teamRHD (League Commissioner / "leitende Stelle")
        ├── seriesOrganizer
        ├── tournamentOrganizer
        ├── delegate
        ├── referee
        ├── teamManager
        ├── sanitater
        ├── scoringTablet
        └── spieler / user
```
