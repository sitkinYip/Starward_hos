import { GameplayLevel, GameplaySnapshot } from './GameplayModels';

/** A readable question may override the scene, including clearing its configured image. */
export function gameplayBackgroundSource(snapshot: GameplaySnapshot | null, level: GameplayLevel | null): string {
  if (snapshot === null || (snapshot.detail.status !== 'active' && snapshot.detail.status !== 'completed') ||
    level === null || level.question === null) {
    return '';
  }
  const override = level.presentationOverride;
  if (override.backgroundMode === 'none') { return ''; }
  if (override.backgroundMode === 'custom') { return override.backgroundUrl ?? ''; }
  return override.backgroundUrl ||
    (snapshot.presentation.backgroundMode === 'none' ? '' : snapshot.presentation.backgroundUrl ?? '');
}
