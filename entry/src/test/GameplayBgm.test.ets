import { describe, expect, it } from '@ohos/hypium';
import { gameplayBgmSource } from '../main/ets/business/GameplayBgm';
import { GameplayLevel, GameplayQuestion, GameplaySnapshot } from '../main/ets/business/GameplayModels';
import { QuestBgmPosition, questBgmCoordinate } from '../main/ets/business/QuestBgmDock';

export default function gameplayBgmTests(): void {
  describe('GameplayBgm', () => {
    it('restoresTheDockWithinTheCurrentSafeAreaAfterResize', 0, () => {
      const saved: QuestBgmPosition = new QuestBgmPosition(0.49, 0.25);
      expect(saved.x).assertEqual(0);
      expect(questBgmCoordinate(saved.y, 800, 40, 24)).assertEqual(216);
      expect(questBgmCoordinate(saved.y, 400, 40, 24)).assertEqual(116);
      expect(questBgmCoordinate(new QuestBgmPosition(0.5, 2).y, 800, 40, 24)).assertEqual(708);
      expect(new QuestBgmPosition(0.5, 2).x).assertEqual(1);
      expect(new QuestBgmPosition(Number.NaN, Number.NaN).y).assertEqual(1);
    });

    it('usesTheViewedQuestionAndHonorsExplicitSilenceOrAnEmptyCustomTrack', 0, () => {
      const snapshot: GameplaySnapshot = new GameplaySnapshot();
      snapshot.detail.status = 'active';
      snapshot.presentation.bgmMode = 'custom';
      snapshot.presentation.bgmUrl = 'https://media.example/session.mp3';
      const inherited: GameplayLevel = new GameplayLevel();
      inherited.question = new GameplayQuestion();
      inherited.presentationOverride.bgmMode = 'inherit';
      const override: GameplayLevel = new GameplayLevel();
      override.question = new GameplayQuestion();
      override.presentationOverride.bgmMode = 'custom';
      override.presentationOverride.bgmUrl = ' https://media.example/level.mp3 ';
      expect(gameplayBgmSource(snapshot, inherited)).assertEqual('https://media.example/session.mp3');
      expect(gameplayBgmSource(snapshot, override)).assertEqual('https://media.example/level.mp3');
      override.presentationOverride.bgmUrl = ' ';
      expect(gameplayBgmSource(snapshot, override)).assertEqual('');
      override.presentationOverride.bgmMode = 'silent';
      expect(gameplayBgmSource(snapshot, override)).assertEqual('');
      snapshot.presentation.bgmMode = 'silent';
      expect(gameplayBgmSource(snapshot, inherited)).assertEqual('');
      override.presentationOverride.bgmMode = 'custom';
      override.presentationOverride.bgmUrl = 'https://media.example/level.mp3';
      expect(gameplayBgmSource(snapshot, override)).assertEqual('https://media.example/level.mp3');
    });

    it('stopsWithoutAReadableAuthorizedQuestionButKeepsCompletedRevisits', 0, () => {
      const snapshot: GameplaySnapshot = new GameplaySnapshot();
      snapshot.detail.status = 'completed';
      snapshot.presentation.bgmUrl = 'https://media.example/session.mp3';
      const level: GameplayLevel = new GameplayLevel();
      expect(gameplayBgmSource(snapshot, level)).assertEqual('');
      level.question = new GameplayQuestion();
      expect(gameplayBgmSource(snapshot, level)).assertEqual('https://media.example/session.mp3');
      expect(gameplayBgmSource(snapshot, null)).assertEqual('');
      expect(gameplayBgmSource(null, level)).assertEqual('');
      snapshot.detail.status = 'cancelled';
      expect(gameplayBgmSource(snapshot, level)).assertEqual('');
      snapshot.detail.status = 'assigned';
      expect(gameplayBgmSource(snapshot, level)).assertEqual('');
    });
  });
}
