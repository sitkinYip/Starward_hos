import { describe, expect, it } from '@ohos/hypium';
import { gameplayBackgroundSource } from '../main/ets/business/GameplayBackground';
import { GameplayLevel, GameplayQuestion, GameplaySnapshot } from '../main/ets/business/GameplayModels';

const SESSION_IMAGE: string = 'https://media.example.com/session.png';
const LEVEL_IMAGE: string = 'https://media.example.com/level.png';

export default function gameplayBackgroundTests(): void {
  describe('GameplayBackground', () => {
    it('inheritsTheSessionImageAndHonorsAnExplicitLevelClear', 0, () => {
      const snapshot: GameplaySnapshot = new GameplaySnapshot();
      snapshot.detail.status = 'active';
      snapshot.presentation.backgroundUrl = SESSION_IMAGE;
      const level: GameplayLevel = new GameplayLevel();
      level.question = new GameplayQuestion();
      level.presentationOverride.backgroundMode = 'inherit';
      expect(gameplayBackgroundSource(snapshot, level)).assertEqual(SESSION_IMAGE);
      level.presentationOverride.backgroundMode = 'none';
      level.presentationOverride.backgroundUrl = LEVEL_IMAGE;
      expect(gameplayBackgroundSource(snapshot, level)).assertEqual('');
    });

    it('keepsLegacyOverridesAndAnEmptyCustomChoice', 0, () => {
      const snapshot: GameplaySnapshot = new GameplaySnapshot();
      snapshot.detail.status = 'active';
      snapshot.presentation.backgroundUrl = SESSION_IMAGE;
      const level: GameplayLevel = new GameplayLevel();
      level.question = new GameplayQuestion();
      level.presentationOverride.backgroundUrl = LEVEL_IMAGE;
      expect(gameplayBackgroundSource(snapshot, level)).assertEqual(LEVEL_IMAGE);
      level.presentationOverride.backgroundMode = 'custom';
      expect(gameplayBackgroundSource(snapshot, level)).assertEqual(LEVEL_IMAGE);
      level.presentationOverride.backgroundUrl = '';
      expect(gameplayBackgroundSource(snapshot, level)).assertEqual('');
      level.presentationOverride.backgroundMode = 'inherit';
      expect(gameplayBackgroundSource(snapshot, level)).assertEqual(SESSION_IMAGE);
      snapshot.presentation.backgroundMode = 'none';
      expect(gameplayBackgroundSource(snapshot, level)).assertEqual('');
      level.presentationOverride.backgroundUrl = LEVEL_IMAGE;
      expect(gameplayBackgroundSource(snapshot, level)).assertEqual(LEVEL_IMAGE);
    });

    it('requiresAnAuthorizedReadableQuestionAndAllowsCompletedRevisits', 0, () => {
      const snapshot: GameplaySnapshot = new GameplaySnapshot();
      snapshot.detail.status = 'completed';
      snapshot.presentation.backgroundUrl = SESSION_IMAGE;
      const level: GameplayLevel = new GameplayLevel();
      expect(gameplayBackgroundSource(snapshot, level)).assertEqual('');
      level.question = new GameplayQuestion();
      expect(gameplayBackgroundSource(snapshot, level)).assertEqual(SESSION_IMAGE);
      expect(gameplayBackgroundSource(snapshot, null)).assertEqual('');
      expect(gameplayBackgroundSource(null, level)).assertEqual('');
      snapshot.detail.status = 'cancelled';
      expect(gameplayBackgroundSource(snapshot, level)).assertEqual('');
      snapshot.detail.status = 'assigned';
      expect(gameplayBackgroundSource(snapshot, level)).assertEqual('');
    });
  });
}
