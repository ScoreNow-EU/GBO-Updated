/**
 * Constraint-satisfaction solver for referee and Kampfgericht assignment.
 *
 * Objective: Maximize the minimum break time between consecutive assignments
 * per official, subject to hard constraints:
 *   - No double-booking (same person cannot referee and do Kampfgericht at same time)
 *   - Availability windows must be respected
 *   - License level requirements must be met for referees
 *   - Manual overrides are honored (fixed assignments)
 *   - Excluded officials per game are respected
 *   - Compatibility rules (who can/cannot work together)
 *
 * The solver uses a greedy heuristic with local search refinement:
 *   1. Sort games by scheduled time
 *   2. For each game, score each eligible official by the break time they'd get
 *   3. Assign the official with the maximum minimum-break delta
 *   4. Local search: swap assignments between games to improve minimum breaks
 */

// ---- Types ----

interface GameInput {
  id: string;
  scheduledTime: string; // ISO 8601
  durationMinutes: number;
  courtId?: string;
}

interface OfficialInput {
  id: string;
  type: "referee" | "kampfgericht" | "kampfgericht_capable_referee";
  licenseLevel?: string;
  availableFrom?: string;
  availableUntil?: string;
  isFullDay: boolean;
}

interface ConstraintInput {
  gameId: string;
  requiredLicenseLevel?: string;
  manualReferee1Id?: string;
  manualReferee2Id?: string;
  manualTimekeeperId?: string;
  manualScorekeeperId?: string;
  excludedOfficialIds: string[];
}

interface CompatibilityInput {
  official1Id: string;
  official2Id: string;
  canWorkTogether: boolean;
}

interface AssignmentResult {
  gameId: string;
  referee1Id: string | null;
  referee2Id: string | null;
  timekeeperId: string | null;
  scorekeeperId: string | null;
}

interface SolverResult {
  assignments: AssignmentResult[];
  breakTimes: Record<string, number[]>;
  isOptimal: boolean;
  warnings: string[];
}

// License level ordering (index = rank, higher = better)
const LICENSE_ORDER = [
  "Entwicklungskader",
  "Leistungskader",
  "Elitekader",
  "EHF Referee",
];

function licenseRank(level: string | undefined): number {
  if (!level) return -1;
  return LICENSE_ORDER.indexOf(level);
}

function meetsLicenseRequirement(
  actual: string | undefined,
  required: string | undefined
): boolean {
  if (!required) return true;
  return licenseRank(actual) >= licenseRank(required);
}

// ---- Internal types ----

interface ParsedGame {
  id: string;
  time: number; // Epoch ms
  endTime: number; // Epoch ms (time + duration)
  durationMinutes: number;
  courtId?: string;
}

interface ParsedOfficial {
  id: string;
  type: "referee" | "kampfgericht" | "kampfgericht_capable_referee";
  licenseLevel?: string;
  availableFrom?: number; // Epoch ms
  availableUntil?: number; // Epoch ms
  isFullDay: boolean;
  /** The real official ID (strips _kg suffix for dual-role refs) */
  realId: string;
}

interface Assignment {
  gameId: string;
  referee1Id: string | null;
  referee2Id: string | null;
  timekeeperId: string | null;
  scorekeeperId: string | null;
}

// ---- Solver ----

export function solveAssignment(
  gamesRaw: GameInput[],
  officialsRaw: OfficialInput[],
  constraintsRaw: ConstraintInput[],
  compatibilitiesRaw: CompatibilityInput[]
): SolverResult {
  const warnings: string[] = [];

  // Parse and sort games by time
  const games: ParsedGame[] = gamesRaw
    .map((g) => {
      const time = new Date(g.scheduledTime).getTime();
      const dur = g.durationMinutes || 40;
      return {
        id: g.id,
        time,
        endTime: time + dur * 60 * 1000,
        durationMinutes: dur,
        courtId: g.courtId,
      };
    })
    .sort((a, b) => a.time - b.time);

  // Parse officials
  const officials: ParsedOfficial[] = officialsRaw.map((o) => ({
    id: o.id,
    type: o.type,
    licenseLevel: o.licenseLevel,
    availableFrom: o.availableFrom
      ? new Date(o.availableFrom).getTime()
      : undefined,
    availableUntil: o.availableUntil
      ? new Date(o.availableUntil).getTime()
      : undefined,
    isFullDay: o.isFullDay,
    realId: o.id.replace(/_kg$/, ""),
  }));

  // Build constraint map
  const constraintMap = new Map<string, ConstraintInput>();
  for (const c of constraintsRaw) {
    constraintMap.set(c.gameId, c);
  }

  // Build compatibility rules (blocked pairs)
  const blockedPairs = new Set<string>();
  for (const c of compatibilitiesRaw) {
    if (!c.canWorkTogether) {
      blockedPairs.add(pairKey(c.official1Id, c.official2Id));
    }
  }

  // Separate referees and kampfgericht-capable officials
  const referees = officials.filter((o) => o.type === "referee");
  const kgOfficials = officials.filter(
    (o) => o.type === "kampfgericht" || o.type === "kampfgericht_capable_referee"
  );

  if (referees.length === 0) {
    warnings.push("Keine Schiedsrichter verfügbar");
  }
  if (kgOfficials.length === 0) {
    warnings.push("Keine Kampfgericht-Mitglieder verfügbar");
  }

  // Track each official's assignment times: realId → sorted list of {start, end}
  const schedule = new Map<string, Array<{ start: number; end: number }>>();

  function getSchedule(
    realId: string
  ): Array<{ start: number; end: number }> {
    let s = schedule.get(realId);
    if (!s) {
      s = [];
      schedule.set(realId, s);
    }
    return s;
  }

  function addToSchedule(realId: string, start: number, end: number): void {
    const s = getSchedule(realId);
    s.push({start, end});
    s.sort((a, b) => a.start - b.start);
  }

  function hasConflict(realId: string, start: number, end: number): boolean {
    const s = getSchedule(realId);
    for (const slot of s) {
      if (start < slot.end && end > slot.start) return true;
    }
    return false;
  }

  function minBreakMinutes(realId: string): number {
    const s = getSchedule(realId);
    if (s.length <= 1) return Infinity;
    let minB = Infinity;
    for (let i = 1; i < s.length; i++) {
      const breakMs = s[i].start - s[i - 1].end;
      const breakMin = Math.round(breakMs / 60000);
      if (breakMin < minB) minB = breakMin;
    }
    return minB;
  }

  function getBreakTimesForOfficial(realId: string): number[] {
    const s = getSchedule(realId);
    const breaks: number[] = [];
    for (let i = 1; i < s.length; i++) {
      breaks.push(Math.round((s[i].start - s[i - 1].end) / 60000));
    }
    return breaks;
  }

  function isAvailable(
    official: ParsedOfficial,
    gameTime: number,
    gameEnd: number
  ): boolean {
    if (official.isFullDay) return true;
    if (official.availableFrom && gameTime < official.availableFrom) return false;
    if (official.availableUntil && gameEnd > official.availableUntil) return false;
    return true;
  }

  // ---- Phase 1: Apply manual overrides ----
  const assignments: Assignment[] = games.map((g) => ({
    gameId: g.id,
    referee1Id: null,
    referee2Id: null,
    timekeeperId: null,
    scorekeeperId: null,
  }));

  const assignmentMap = new Map<string, Assignment>();
  for (const a of assignments) {
    assignmentMap.set(a.gameId, a);
  }

  for (const game of games) {
    const c = constraintMap.get(game.id);
    if (!c) continue;
    const a = assignmentMap.get(game.id)!;

    if (c.manualReferee1Id) {
      a.referee1Id = c.manualReferee1Id;
      addToSchedule(c.manualReferee1Id, game.time, game.endTime);
    }
    if (c.manualReferee2Id) {
      a.referee2Id = c.manualReferee2Id;
      addToSchedule(c.manualReferee2Id, game.time, game.endTime);
    }
    if (c.manualTimekeeperId) {
      a.timekeeperId = c.manualTimekeeperId;
      addToSchedule(
        c.manualTimekeeperId.replace(/_kg$/, ""),
        game.time,
        game.endTime
      );
    }
    if (c.manualScorekeeperId) {
      a.scorekeeperId = c.manualScorekeeperId;
      addToSchedule(
        c.manualScorekeeperId.replace(/_kg$/, ""),
        game.time,
        game.endTime
      );
    }
  }

  // ---- Phase 2: Greedy assignment ----

  // For each game (in time order), assign remaining roles
  for (const game of games) {
    const a = assignmentMap.get(game.id)!;
    const c = constraintMap.get(game.id);
    const excluded = new Set(c?.excludedOfficialIds ?? []);

    // Get already assigned real IDs for this game (to avoid double-booking within game)
    const assignedInGame = new Set<string>();
    if (a.referee1Id) assignedInGame.add(a.referee1Id);
    if (a.referee2Id) assignedInGame.add(a.referee2Id);
    if (a.timekeeperId) assignedInGame.add(a.timekeeperId.replace(/_kg$/, ""));
    if (a.scorekeeperId)
      assignedInGame.add(a.scorekeeperId.replace(/_kg$/, ""));

    // Assign referees
    if (!a.referee1Id) {
      const best = findBestOfficial(
        referees,
        game,
        excluded,
        assignedInGame,
        c?.requiredLicenseLevel,
        blockedPairs,
        null // no partner constraint for ref1
      );
      if (best) {
        a.referee1Id = best.id;
        assignedInGame.add(best.realId);
        addToSchedule(best.realId, game.time, game.endTime);
      } else {
        warnings.push(
          `Kein SR1 für Spiel ${game.id} gefunden`
        );
      }
    }

    if (!a.referee2Id) {
      const best = findBestOfficial(
        referees,
        game,
        excluded,
        assignedInGame,
        c?.requiredLicenseLevel,
        blockedPairs,
        a.referee1Id // must be compatible with ref1
      );
      if (best) {
        a.referee2Id = best.id;
        assignedInGame.add(best.realId);
        addToSchedule(best.realId, game.time, game.endTime);
      } else {
        warnings.push(
          `Kein SR2 für Spiel ${game.id} gefunden`
        );
      }
    }

    // Assign timekeeper
    if (!a.timekeeperId) {
      const best = findBestOfficial(
        kgOfficials,
        game,
        excluded,
        assignedInGame,
        undefined, // no license requirement for KG
        blockedPairs,
        null
      );
      if (best) {
        a.timekeeperId = best.id;
        assignedInGame.add(best.realId);
        addToSchedule(best.realId, game.time, game.endTime);
      } else {
        warnings.push(
          `Kein Zeitnehmer für Spiel ${game.id} gefunden`
        );
      }
    }

    // Assign scorekeeper
    if (!a.scorekeeperId) {
      const best = findBestOfficial(
        kgOfficials,
        game,
        excluded,
        assignedInGame,
        undefined,
        blockedPairs,
        a.timekeeperId // must not conflict with timekeeper
      );
      if (best) {
        a.scorekeeperId = best.id;
        assignedInGame.add(best.realId);
        addToSchedule(best.realId, game.time, game.endTime);
      } else {
        warnings.push(
          `Kein Sekretär für Spiel ${game.id} gefunden`
        );
      }
    }
  }

  /**
   * Find the best available official for a game role.
   * Scores by: how much break time they'd still have.
   * Prefers the official whose minimum break (after this assignment) is largest.
   */
  function findBestOfficial(
    pool: ParsedOfficial[],
    game: ParsedGame,
    excluded: Set<string>,
    assignedInGame: Set<string>,
    requiredLicense: string | undefined,
    blocked: Set<string>,
    partnerId: string | null
  ): ParsedOfficial | null {
    let bestOfficial: ParsedOfficial | null = null;
    let bestScore = -Infinity;

    for (const official of pool) {
      // Skip if excluded
      if (excluded.has(official.id) || excluded.has(official.realId)) continue;

      // Skip if already assigned in this game
      if (assignedInGame.has(official.realId)) continue;

      // Check availability
      if (!isAvailable(official, game.time, game.endTime)) continue;

      // Check license requirement (only for referees)
      if (
        requiredLicense &&
        official.type === "referee" &&
        !meetsLicenseRequirement(official.licenseLevel, requiredLicense)
      ) {
        continue;
      }

      // Check time conflict
      if (hasConflict(official.realId, game.time, game.endTime)) continue;

      // Check compatibility with partner
      if (partnerId) {
        const partnerRealId = partnerId.replace(/_kg$/, "");
        if (blocked.has(pairKey(official.realId, partnerRealId))) continue;
      }

      // Score: simulate adding this assignment and check min break
      const currentSchedule = getSchedule(official.realId);
      // Temporarily add
      const tempSlots = [
        ...currentSchedule,
        {start: game.time, end: game.endTime},
      ].sort((a, b) => a.start - b.start);

      let minB = Infinity;
      for (let i = 1; i < tempSlots.length; i++) {
        const breakMin = Math.round(
          (tempSlots[i].start - tempSlots[i - 1].end) / 60000
        );
        if (breakMin < minB) minB = breakMin;
      }

      // If they have no other assignments yet, give them a high score
      // but slightly lower than officials with a guaranteed break
      const score =
        tempSlots.length === 1
          ? 10000 - currentSchedule.length // Prefer less-used officials
          : minB;

      if (score > bestScore) {
        bestScore = score;
        bestOfficial = official;
      }
    }

    return bestOfficial;
  }

  // ---- Phase 3: Local search refinement ----
  // Try swapping pairs of same-role assignments between games to improve breaks
  let improved = true;
  let iterations = 0;
  const MAX_ITERATIONS = 100;

  while (improved && iterations < MAX_ITERATIONS) {
    improved = false;
    iterations++;

    for (let i = 0; i < games.length; i++) {
      for (let j = i + 1; j < games.length; j++) {
        const a1 = assignmentMap.get(games[i].id)!;
        const a2 = assignmentMap.get(games[j].id)!;

        // Try swapping referee1
        if (a1.referee1Id && a2.referee1Id && a1.referee1Id !== a2.referee1Id) {
          if (
            trySwap(
              a1,
              a2,
              "referee1Id",
              games[i],
              games[j],
              constraintMap,
              referees
            )
          ) {
            improved = true;
          }
        }

        // Try swapping referee2
        if (a1.referee2Id && a2.referee2Id && a1.referee2Id !== a2.referee2Id) {
          if (
            trySwap(
              a1,
              a2,
              "referee2Id",
              games[i],
              games[j],
              constraintMap,
              referees
            )
          ) {
            improved = true;
          }
        }

        // Try swapping timekeeper
        if (
          a1.timekeeperId &&
          a2.timekeeperId &&
          a1.timekeeperId !== a2.timekeeperId
        ) {
          if (
            trySwap(
              a1,
              a2,
              "timekeeperId",
              games[i],
              games[j],
              constraintMap,
              kgOfficials
            )
          ) {
            improved = true;
          }
        }

        // Try swapping scorekeeper
        if (
          a1.scorekeeperId &&
          a2.scorekeeperId &&
          a1.scorekeeperId !== a2.scorekeeperId
        ) {
          if (
            trySwap(
              a1,
              a2,
              "scorekeeperId",
              games[i],
              games[j],
              constraintMap,
              kgOfficials
            )
          ) {
            improved = true;
          }
        }
      }
    }
  }

  /**
   * Try swapping a role between two assignments.
   * Returns true if the swap improved the global minimum break.
   */
  function trySwap(
    a1: Assignment,
    a2: Assignment,
    role: "referee1Id" | "referee2Id" | "timekeeperId" | "scorekeeperId",
    g1: ParsedGame,
    g2: ParsedGame,
    cMap: Map<string, ConstraintInput>,
    _pool: ParsedOfficial[]
  ): boolean {
    const id1 = a1[role];
    const id2 = a2[role];
    if (!id1 || !id2) return false;

    const realId1 = id1.replace(/_kg$/, "");
    const realId2 = id2.replace(/_kg$/, "");

    // Check constraints
    const c1 = cMap.get(g1.id);
    const c2 = cMap.get(g2.id);

    // Don't swap manual overrides
    if (c1 && getManualForRole(c1, role)) return false;
    if (c2 && getManualForRole(c2, role)) return false;

    // Check exclusions
    if (c1 && c1.excludedOfficialIds.includes(id2)) return false;
    if (c2 && c2.excludedOfficialIds.includes(id1)) return false;

    // Compute current min breaks for both officials
    const currentMin1 = minBreakMinutes(realId1);
    const currentMin2 = minBreakMinutes(realId2);
    const currentOverall = Math.min(currentMin1, currentMin2);

    // Simulate swap: remove old slots, add new ones
    removeFromSchedule(realId1, g1.time, g1.endTime);
    removeFromSchedule(realId2, g2.time, g2.endTime);
    addToSchedule(realId1, g2.time, g2.endTime);
    addToSchedule(realId2, g1.time, g1.endTime);

    // Check for conflicts after swap
    const conflict1 = hasConflictExcluding(realId1, g2.time, g2.endTime);
    const conflict2 = hasConflictExcluding(realId2, g1.time, g1.endTime);

    const newMin1 = minBreakMinutes(realId1);
    const newMin2 = minBreakMinutes(realId2);
    const newOverall = Math.min(newMin1, newMin2);

    if (!conflict1 && !conflict2 && newOverall > currentOverall) {
      // Accept swap
      a1[role] = id2;
      a2[role] = id1;
      return true;
    } else {
      // Revert
      removeFromSchedule(realId1, g2.time, g2.endTime);
      removeFromSchedule(realId2, g1.time, g1.endTime);
      addToSchedule(realId1, g1.time, g1.endTime);
      addToSchedule(realId2, g2.time, g2.endTime);
      return false;
    }
  }

  function removeFromSchedule(
    realId: string,
    start: number,
    end: number
  ): void {
    const s = getSchedule(realId);
    const idx = s.findIndex(
      (slot) => slot.start === start && slot.end === end
    );
    if (idx !== -1) s.splice(idx, 1);
  }

  function hasConflictExcluding(
    realId: string,
    _start: number,
    _end: number
  ): boolean {
    // Check if ANY pair of slots now overlap
    const s = getSchedule(realId);
    for (let i = 1; i < s.length; i++) {
      if (s[i].start < s[i - 1].end) return true;
    }
    return false;
  }

  function getManualForRole(
    c: ConstraintInput,
    role: string
  ): string | undefined {
    switch (role) {
      case "referee1Id":
        return c.manualReferee1Id;
      case "referee2Id":
        return c.manualReferee2Id;
      case "timekeeperId":
        return c.manualTimekeeperId;
      case "scorekeeperId":
        return c.manualScorekeeperId;
      default:
        return undefined;
    }
  }

  // ---- Build result ----

  // Compute per-official break times
  const breakTimes: Record<string, number[]> = {};
  const allRealIds = new Set<string>();
  for (const a of assignments) {
    if (a.referee1Id) allRealIds.add(a.referee1Id);
    if (a.referee2Id) allRealIds.add(a.referee2Id);
    if (a.timekeeperId) allRealIds.add(a.timekeeperId.replace(/_kg$/, ""));
    if (a.scorekeeperId) allRealIds.add(a.scorekeeperId.replace(/_kg$/, ""));
  }

  for (const realId of allRealIds) {
    const breaks = getBreakTimesForOfficial(realId);
    if (breaks.length > 0) {
      breakTimes[realId] = breaks;
    }
  }

  // Determine optimality
  const isOptimal =
    warnings.length === 0 &&
    assignments.every(
      (a) =>
        a.referee1Id !== null &&
        a.referee2Id !== null &&
        a.timekeeperId !== null &&
        a.scorekeeperId !== null
    );

  return {
    assignments,
    breakTimes,
    isOptimal,
    warnings,
  };
}

function pairKey(id1: string, id2: string): string {
  return [id1, id2].sort().join("|");
}
