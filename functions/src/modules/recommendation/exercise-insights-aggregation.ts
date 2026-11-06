import type {ExerciseCompatibility, ExerciseInsightGroup, ProvisionalSamplePolicy, SessionEvidence} from './exercise-insights-contracts';

export interface MemberEvidence {readonly memberId: string; readonly sessions: readonly SessionEvidence[]}
interface MemberGroup {scores: number[]; qualified: SessionEvidence[]}
interface Group {
  compatibility: ExerciseCompatibility; sessions: number; scored: number; attempts: number;
  tracked: number; rejected: number; dates: Set<string>; members: Map<string, MemberGroup>;
}
/** Pure aggregation. Member keys are used only internally, never projected into the result. */
export function aggregateExerciseEvidence(evidence: readonly MemberEvidence[], policy: ProvisionalSamplePolicy | null): ExerciseInsightGroup[] {
  const groups = new Map<string, Group>();
  for (const member of evidence) for (const s of member.sessions) {
    if (!s.compatibility) continue;
    const key = JSON.stringify(s.compatibility);
    let g = groups.get(key);
    if (!g) {
      g = {compatibility: s.compatibility, sessions: 0, scored: 0, attempts: 0,
        tracked: 0, rejected: 0, dates: new Set(), members: new Map()};
      groups.set(key, g);
    }
    let m = g.members.get(member.memberId);
    if (!m) {m = {scores: [], qualified: []}; g.members.set(member.memberId, m);}
    g.sessions++; g.attempts += s.assessedAttempts; g.tracked += s.trackedMicros; g.rejected += s.rejectedMicros;
    g.dates.add(s.localDate);
    if (s.formScorePercent !== null && s.compatibility.scoreSupport === 'scored') {
      g.scored++; m.scores.push(s.formScorePercent);
      if (policy && s.trackingCoverage !== null && s.trackingCoverage >= policy.minimumTrackingCoverage) m.qualified.push(s);
    }
  }
  // This is identity ordering for descriptive groups, not cross-exercise severity ranking.
  return [...groups.entries()].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).map(([, g]) => {
    const means = [...g.members.values()].filter(m => m.scores.length).map(m => m.scores.reduce((a, b) => a + b, 0) / m.scores.length);
    const meeting = policy === null ? null : [...g.members.values()].filter(m =>
      m.qualified.length >= policy.minimumScoredSessions &&
      new Set(m.qualified.map(s => s.localDate)).size >= policy.minimumDistinctDays &&
      m.qualified.reduce((n, s) => n + s.assessedAttempts, 0) >= policy.minimumAssessedAttempts).length;
    return {compatibility: g.compatibility, sessions: g.sessions, members: g.members.size,
      scoredSessions: g.scored, missingScoreSessions: g.compatibility.scoreSupport === 'scored' ? g.sessions - g.scored : 0,
      unscoredSessions: g.compatibility.scoreSupport === 'unscored' ? g.sessions : 0, assessedAttempts: g.attempts,
      distinctSessionDays: g.dates.size, meanEstimatedFormScore: means.length ? means.reduce((a, b) => a + b, 0) / means.length : null,
      trackedMicros: g.tracked, rejectedMicros: g.rejected,
      trackingCoverage: g.tracked + g.rejected ? g.tracked / (g.tracked + g.rejected) : null,
      membersMeetingProvisionalMinimums: g.compatibility.scoreSupport === 'unscored' ? null : meeting,
      evidenceState: g.compatibility.scoreSupport === 'unscored' ? 'unscored' : !g.scored ? 'no_scored_samples'
        : policy === null ? 'policy_not_configured' : meeting === 0 ? 'insufficient_evidence' : 'meets_provisional_minimums'};
  });
}
