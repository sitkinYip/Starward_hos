import { AssignmentSummary } from '../business/models';

export interface PassportSummary {
  solved: number | null;
  sessions: number | null;
  rewards: number | null;
}

/** Only successful, owner-bound snapshots can contribute a numeric count. */
export function summarizePassport(assignments: AssignmentSummary[] | null, rewards: number | null): PassportSummary {
  if (assignments === null) {
    return { solved: null, sessions: null, rewards };
  }
  let solved: number = 0;
  let sessions: number = 0;
  for (const assignment of assignments) {
    solved += assignment.completedLevels;
    if (assignment.status !== 'cancelled') { sessions++; }
  }
  return { solved, sessions, rewards };
}
