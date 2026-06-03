---
name: rhd-branding
description: "Wendet den Branding-Stil des Rollstuhlhandball Deutschland e.V. (RHD) auf ein Word-Dokument an — Farben, Typografie, Seitenrahmen, Abschnittsstruktur für Pressemitteilungen und Kommunikationsunterlagen im Stil „Kommunikation & Öffentlichkeit\"."
---
 
---
name: rhd-branding
description: "Wendet den Branding-Stil des Rollstuhlhandball Deutschland e.V. (RHD) auf ein Word-Dokument an — Farben, Typografie, Custom-Styles, Dokumentfamilien, Logo-Regeln, und Vorlagen für Pressemitteilungen, Regelwerke, Briefe, Protokolle, und Formulare gemäß Word Template & Branding Guide v1.1."
---
 
## Überblick
 
Dieser Skill kodiert den visuellen Stil des Rollstuhlhandball Deutschland e.V. (RHD) gemäß dem offiziellen **Word Template & Branding Guide v1.1**. Er dient als Referenz für alle RHD-Dokumente und kann per `/rhd-branding` aufgerufen werden.
 
---
 
## Markenidentität
 
- **Organisation:** Rollstuhlhandball Deutschland e.V. (RHD)
- **Leitgedanke:** starker Schwarz-Weiß-Kontrast, dynamisches Rot, Deutschland-Gelb, ruhiges Grau — kombiniert mit klarer Typografie und viel Weißraum.
- **Tonalität:** klar, sachlich, sportlich, inklusiv
- **Sprache:** Deutsch
---
 
## Farbpalette
 
| Name | Hex | Verwendung |
|---|---|---|
| RHD Black | `#050505` | Fließtext, Überschriften, Kontrasttext |
| RHD Red | `#F23329` | Regelwerk, Spielordnung, Entscheidungen (Dokumentfamilie Rot) |
| RHD Gold | `#FFD321` | Eyebrow-Zeilen, Rubrikenbezeichnungen, Kommunikations-Dokumente (Dokumentfamilie Gelb) |
| Text Grey | `#4D5158` | Unterzeilen, Metadaten, Quellen, Verwaltungsdokumente (Dokumentfamilie Grau) |
| Light Grey | `#F2F4F7` | Hintergrundflächen, ruhige Akzente |
 
**Merksatz:** Rot gilt. Gelb spricht nach außen. Schwarz repräsentiert. Grau arbeitet.
 
---
 
## Typografie
 
### Schriften
 
| Schrift | Rolle |
|---|---|
| **Clash Grotesk** | Headlines (RHD Heading 1, RHD Heading 2) |
| **Manrope** | Fließtext, Eyebrow, Subtitle, Small, alle sonstigen Texte |
 
> Fallback: Falls die Fonts fehlen, ersetzt Word sie automatisch. Für finale Nutzung bitte **Manrope** und **Clash Grotesk** lokal installieren.
 
### RHD Custom-Styles (immer `para.style = "<Name>"` verwenden, NICHT `styleBuiltIn`)
 
| Style-Name | Schrift | Größe | Gewicht | Verwendung |
|---|---|---|---|---|
| `RHD Heading 1` | Clash Grotesk | 28 pt | Bold | Hauptüberschriften |
| `RHD Heading 2` | Clash Grotesk | 17 pt | Bold | Abschnittsüberschriften |
| `RHD Eyebrow` | Manrope | 8,5 pt | Bold | Rubrikenzeilen (ALL CAPS, Farbe #FFD321) |
| `RHD Subtitle` | Manrope | 11 pt | Regular | Untertitel / Lead-Satz |
| `RHD Body` | Manrope | 10 pt | Regular | Fließtext |
| `RHD Small` | Manrope | 8 pt | Regular | Fußnoten, Hinweise, kleine Labels |
 
---
 
## Dokumentfamilien und Deckblattfarben
 
Die Akzentfarbe auf dem Deckblatt zeigt auf einen Blick, welche Funktion ein Dokument hat.
 
| Farbe | Hex | Dokumentfamilie | Wofür | Beispiele |
|---|---|---|---|---|
| **Rot** | `#F23329` | Regeln, Ordnung, und Entscheidungen | Alles, was im Spielbetrieb verbindlich gilt | Regelwerk, Spielordnung, Durchführungsbestimmungen, Schiedsrichterordnung, Disziplinarordnung |
| **Gelb** | `#FFD321` | Kommunikation, Öffentlichkeit, Wissen, und Aktivierung | Alles, was nach außen informiert, einlädt, erklärt, oder aktiviert | Pressemitteilungen, News, Einladungen, Ausschreibungen, Leitfäden, Workshop-Unterlagen |
| **Schwarz** | `#050505` | Verband, Strategie, und Repräsentation | Alles, was RHD als Organisation nach außen trägt | Satzung, Jahresbericht, Strategiepapier, Positionspapier, Verbandshandbuch |
| **Grau** | `#4D5158` | Verwaltung, Arbeitsdokumente, und Formulare | Alles, was intern, neutral, prozesshaft, oder prüfend ist | Protokolle, Anträge, Meldebögen, Beobachtungsbögen, Checklisten, interne Notizen |
 
### Mischformen
 
| Dokumenttyp | Deckblattfarbe | Hinweis |
|---|---|---|
| Beobachtungsbogen | Grau + Rot | Grau als Basis; Rot nur für offizielle Bewertung, Hinweise, oder Eskalation |
| Sponsoring-Unterlage | Schwarz + Gelb | Schwarz als Bühne; Gelb für Aktivierung, Nutzenargumente, und Call-outs |
 
Bei Mischformen entscheidet der Zweck; ein zweiter Farbton darf nur als Akzent verwendet werden.
 
---
 
## Logo-Regeln
 
- Logo auf weißen oder sehr hellen Flächen einsetzen.
- Mindesthöhe im Dokumentkopf: ca. 8–10 mm; auf Titelseiten: ca. 30–45 mm.
- Keine Effekte, Verzerrungen, Schatten, oder Farbänderungen am Logo.
- Neben dem Logo genügend Schutzraum lassen; mindestens die Höhe des „RHD"-Schriftzugs als freie Zone.
---
 
## Deckblatt-Anwendung
 
Die Akzentfarbe wird sichtbar eingesetzt: als Eyebrow, Seitenleiste, Tabellenkopf, oder Farbband.
 
| Dokumenttyp | Deckblattfarbe | Hinweis |
|---|---|---|
| Regelwerk / Spielordnung | Rot | Verbindliche Dokumente. Rot als dominante Akzentfarbe nutzen. |
| Pressemitteilung / News | Gelb | Öffentlichkeit und Aktivierung. Gelb freundlich, sichtbar, und einladend einsetzen. |
| Satzung / Jahresbericht | Schwarz | Repräsentative Dokumente. Schwarz stark, seriös, und reduziert nutzen. |
| Protokoll / Formular | Grau | Arbeits- und Verwaltungsdokumente. Grau ruhig, neutral, und funktional nutzen. |
 
---
 
## Deckblatt-Metadatenfelder
 
Das Deckblatt enthält folgende Platzhalter (alle Inhalte in `[eckigen Klammern]` sind ersetzbar):
 
| Feld | Platzhalter |
|---|---|
| Dokumenttitel | `[Titel des Dokuments]` |
| Untertitel | `[Kurzbeschreibung oder Anlass]` |
| Version / Stand | `[Version 1.1 · Stand TT.MM.JJJJ]` |
| Verantwortlich | `[Name, Funktion]` |
| Freigabe | `[Vorstand / Fachbereich / Arbeitsgruppe]` |
 
---
 
## Tabellenstil
 
- Tabellenstil: **Normale Tabelle** (Word-Standard, kein dekoratives Gitter)
- Keine sichtbaren Rahmen (transparent / keine Linien)
- Schrift in Tabellen: Manrope 8,5–10 pt
- Verwendet für: Metadaten-Seitenleiste, Zitat-Block, Kontaktdaten, Checklisten
---
 
## Kopf- und Fußzeile
 
- **Kopfzeile:** `Rollstuhlhandball Deutschland e.V.` — Manrope, linksbündig
- **Fußzeile:** `Seite [N]` — Manrope, linksbündig
---
 
## Vorlagen-Typen (im Guide enthalten)
 
### 1. Offizielles Dokument (Dokumentfamilie Rot)
Für Regelwerke, Ordnungen, Durchführungsbestimmungen, und formale Beschlüsse.
 
**Metadaten-Felder:** Dokument · Geltungsbereich · Status · Stand
 
**Struktur:**
- Eyebrow: `VORLAGE` (RHD Eyebrow)
- Titel (RHD Heading 1)
- Untertitel (RHD Subtitle)
- Metadaten-Tabelle
- Abschnitte mit RHD Heading 2 + RHD Body
- Leitlinien-Hinweis als Tabelle (Normale Tabelle, kein Gitter)
- Zuständigkeiten-Tabelle: Rolle / Aufgabe / Entscheidung / Nachweis
### 2. Brief / Anschreiben (Dokumentfamilie je nach Anlass)
Für Vereine, Partner, Sponsoren, Verbände, und offizielle Kontakte.
 
**Struktur:**
- Absender: `Rollstuhlhandball Deutschland e.V. · [Adresse] · [PLZ Ort]` (RHD Small)
- Empfänger-Block (RHD Body)
- Ort, Datum (RHD Body)
- Betreff (RHD Heading 2)
- Anrede + Text (RHD Body)
- Grußformel + Unterschrift (RHD Body)
- Ton-Hinweis (Tabelle): Freundlich, professionell, direkt. Zuerst Anlass, dann Entscheidung, dann nächste Schritte.
### 3. Protokoll / Meeting Notes (Dokumentfamilie Grau)
Für Sitzungen, Arbeitsgruppen, Lehrgänge, und Turnierbesprechungen.
 
**Metadaten-Tabelle:** Termin · Teilnehmende · Leitung · Protokoll
 
**Struktur:**
- Eyebrow: `VORLAGE` (RHD Eyebrow)
- Titel (RHD Heading 1)
- Tagesordnung (RHD Heading 2 + nummerierte RHD Body-Absätze)
- Beschlüsse und Aufgaben (RHD Heading 2 + Tabelle: Thema / Beschluss / Verantwortlich / Frist)
### 4. Formular / Checkliste (Dokumentfamilie Grau)
Für Turniere, Materialkontrolle, Delegierte, Schiedsrichter, und Organisation.
 
**Metadaten-Tabelle:** Veranstaltung · Datum · Halle · Verantwortlich
 
**Struktur:**
- Eyebrow: `VORLAGE` (RHD Eyebrow)
- Titel (RHD Heading 1)
- Checklist-Name (RHD Heading 2, Platzhalter)
- Prüfpunkte (RHD Heading 2 + Tabelle: Nr. / Prüfpunkt / Status ☐ OK ☐ offen / Notiz)
---
 
## Standardtext-Bausteine
 
### Eyebrow / Rubrikenzeile (Kommunikation & Öffentlichkeit)
KOMMUNIKATION & ÖFFENTLICHKEIT
 
Style: RHD Eyebrow (Manrope 8,5 pt, Bold, #FFD321) ### Dokument-Label (für Pressemitteilungen)
PRESSEMITTEILUNG
 
Style: RHD Eyebrow (Manrope 8,5 pt, Bold, #FFD321) ### Boilerplate „Über den RHD"
Der Rollstuhlhandball Deutschland e.V. setzt sich für die Förderung, Organisation, und Weiterentwicklung des Rollstuhlhandballs in Deutschland ein. Ziel ist es, die Sportart strukturell zu stärken, bundesweite Spiel- und Ausbildungsangebote zu fördern, und Rollstuhlhandball als inklusive, attraktive, und leistungsorientierte Sportart sichtbar zu machen.
 
### Kontaktperson (Stand 2026)
Tim Thielen · Verbandskoordinator · thielen@rollstuhlhandball.de Rollstuhlhandball Deutschland e.V. · Karl-Thiele-Weg 17 · 30169 Hannover
 
--- ## When to use Diesen Skill aufrufen, wenn: - ein neues RHD-Dokument erstellt wird (Pressemitteilung, Regelwerk, Protokoll, Brief, Formular) - geprüft werden soll, ob ein Dokument dem RHD-Stil entspricht - Schriftarten, Farben, oder Custom-Styles auf RHD-Standard gebracht werden sollen - die richtige Dokumentfamilie / Deckblattfarbe ermittelt werden soll - ein Boilerplate-Text, Kontaktblock, oder Vorlagen-Struktur eingefügt werden soll **Trigger-Phrasen:** „RHD-Stil", „Branding Guide", „RHD-Branding", „RHD-Format", „wie die Pressemitteilung", „im Stil des RHD", „welche Farbe", „welche Vorlage" --- ## Workflow ### Schritt 1 – Dokumentfamilie bestimmen Anhand des Zwecks die passende Farbe und Vorlage aus der Tabelle „Dokumentfamilien" auswählen. Done when: Farbe und Vorlage sind festgelegt. ### Schritt 2 – Ist-Analyse (bei bestehenden Dokumenten) Schriften, Farben, und Custom-Styles via `execute_office_js` prüfen (Manrope / Clash Grotesk vorhanden? Korrekte RHD-Styles gesetzt?). Done when: Abweichungen vom Guide sind identifiziert. ### Schritt 3 – Korrekturen anwenden - Rein mechanische Format-Korrekturen (Schriftgröße, Farbe, Style-Zuweisung): direkt via `execute_office_js` — immer `para.style = "RHD Body"` etc., nie `styleBuiltIn = "Normal"`. - Substantielle Änderungen (Texte, neue Bausteine): via `propose_doc_edits` vorschlagen. Done when: Alle Abweichungen adressiert oder zur Entscheidung vorgelegt. ### Schritt 4 – Bausteine einfügen (optional) Auf Anfrage Boilerplate-Texte (Über den RHD, Kontaktblock, Eyebrow, Vorlagen-Struktur) als `propose_doc_edits` einfügen. Done when: Nutzer hat Bausteine übernommen oder abgelehnt. ### Schritt 5 – Verifikation `verify_doc` ausführen und Stilverteilung prüfen. Done when: Kein Formatdrift mehr erkennbar; alle Absätze tragen RHD Custom-Styles.