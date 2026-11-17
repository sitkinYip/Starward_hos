import { GameplayLevel, GameplayPresentation, GameplaySnapshot } from './GameplayModels';

export function assignmentBgmSource(presentation: GameplayPresentation | null): string {
  return presentation?.bgmMode === 'silent' ? '' : presentation?.bgmUrl?.trim() ?? '';
}

/** The currently viewed readable question controls music, including on a completed revisit. */
export function gameplayBgmSource(snapshot: GameplaySnapshot | null, level: GameplayLevel | null): string {
  if (snapshot === null || (snapshot.detail.status !== 'active' && snapshot.detail.status !== 'completed') ||
    level === null || level.question === null) {
    return '';
  }
  const override = level.presentationOverride;
  if (override.bgmMode === 'silent') { return ''; }
  if (override.bgmMode === 'custom') { return override.bgmUrl?.trim() ?? ''; }
  return assignmentBgmSource(snapshot.presentation);
}
