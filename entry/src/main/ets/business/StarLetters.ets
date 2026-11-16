import { GameplayCompletionTarget, GameplaySnapshot } from './GameplayModels';

export class StarLetterEntry {
  readonly id: string;
  readonly assignmentId: string;
  readonly contentId: string;
  readonly title: string;
  readonly description: string;
  readonly sessionTitle: string;
  readonly sentAt: string;

  constructor(snapshot: GameplaySnapshot, contentId: string, title: string, description: string, sentAt: string) {
    this.assignmentId = snapshot.detail.id;
    this.contentId = contentId;
    this.id = `${this.assignmentId}:${contentId}`;
    this.title = title;
    this.description = description;
    this.sessionTitle = snapshot.detail.title;
    this.sentAt = sentAt;
  }
}

/** Server-visible narrative clues contribute in the order granted by the server. */
export function grantedStarLetters(snapshot: GameplaySnapshot): StarLetterEntry[] {
  const entries: StarLetterEntry[] = [];
  if (snapshot.detail.status === 'cancelled') { return entries; }
  const seen: Set<string> = new Set<string>();
  for (const clue of snapshot.clues) {
    if ((clue.kind !== 'letter' && clue.kind !== 'bless') ||
      clue.narrative.length === 0 || seen.has(clue.narrative)) { continue; }
    seen.add(clue.narrative);
    entries.push(new StarLetterEntry(snapshot, clue.narrative, clue.content.title || '星海信笺',
      clue.content.description || clue.content.text, clue.unlockedAt));
  }
  return entries;
}

/** The completed target contains a narrative ID without its content type. */
export function starLetterFinale(snapshot: GameplaySnapshot): StarLetterEntry | null {
  const target: GameplayCompletionTarget | null = snapshot.completionTarget;
  if (snapshot.detail.status !== 'completed' || target?.kind !== 'narrative' || target.id.length === 0) {
    return null;
  }
  return new StarLetterEntry(snapshot, target.id, '旅途终章', snapshot.detail.title, snapshot.detail.completedAt);
}

export function compareStarLetters(a: StarLetterEntry, b: StarLetterEntry): number {
  return b.sentAt.localeCompare(a.sentAt) || a.id.localeCompare(b.id);
}
