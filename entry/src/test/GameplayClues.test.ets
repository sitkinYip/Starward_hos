import { describe, expect, it } from '@ohos/hypium';
import { clueImageSources, ClueSpan, ClueTextPart, clueTextParts, clueTitle, combinationClues, completionCombinations,
  ordinaryClues } from '../main/ets/business/GameplayClues';
import { GameplayClue, GameplayEffect, GameplayLevel, GameplayQuestion,
  GameplaySnapshot } from '../main/ets/business/GameplayModels';

function level(id: string, completed: boolean = true): GameplayLevel {
  const result: GameplayLevel = new GameplayLevel();
  result.id = id;
  result.question = new GameplayQuestion();
  result.question.id = 'repeated-question';
  result.completedAt = completed ? '2026-11-11T00:00:00.000Z' : '';
  return result;
}

function clue(id: string, kind: string = 'text', source: string = 'session',
  binding: string = '', trigger: string = 'level_completed'): GameplayClue {
  const result: GameplayClue = new GameplayClue();
  result.id = id;
  result.kind = kind;
  result.source = source;
  result.sessionLevel = binding;
  result.trigger = trigger;
  result.question = source === 'question' ? 'repeated-question' : '';
  return result;
}

function snapshot(levels: GameplayLevel[], clues: GameplayClue[]): GameplaySnapshot {
  const result: GameplaySnapshot = new GameplaySnapshot();
  result.detail.status = 'active';
  result.detail.totalLevels = levels.length;
  result.levels = levels;
  result.clues = clues;
  return result;
}

function visibleIds(result: GameplaySnapshot | null, active: GameplayLevel | null): string {
  return ordinaryClues(result, active).map((row: GameplayClue) => row.id).join(',');
}

function plainText(part: ClueTextPart): string {
  return part.spans.map((span: ClueSpan) => span.text).join('');
}

function effect(clueId: string): GameplayEffect {
  const result: GameplayEffect = new GameplayEffect();
  result.clueId = clueId;
  return result;
}

export default function gameplayCluesTests(): void {
  describe('GameplayClues', () => {
    it('usesOnlyCurrentReadableCompletedLevelAndServerGrantedRows', 0, () => {
      const first: GameplayLevel = level('first', false);
      const second: GameplayLevel = level('second');
      const result: GameplaySnapshot = snapshot([first, second], [clue('global')]);
      expect(visibleIds(null, second)).assertEqual('');
      expect(visibleIds(result, null)).assertEqual('');
      expect(visibleIds(result, first)).assertEqual('');
      expect(visibleIds(result, second)).assertEqual('global');
      result.clues = [];
      expect(visibleIds(result, second)).assertEqual('');
      result.clues = [clue('global')];
      second.question = null;
      expect(visibleIds(result, second)).assertEqual('');
      second.question = new GameplayQuestion();
      result.detail.status = 'cancelled';
      expect(visibleIds(result, second)).assertEqual('');
    });

    it('doesNotShareQuestionGrantsAcrossRepeatedQuestionInstances', 0, () => {
      const first: GameplayLevel = level('first');
      const second: GameplayLevel = level('second');
      const result: GameplaySnapshot = snapshot([first, second], [
        clue('source-first', 'text', 'question', 'first', 'question_completed'),
        clue('source-second', 'text', 'question', 'second', 'question_completed'),
        clue('unbound-question', 'text', 'question', '', 'question_completed'),
        clue('bound-second', 'text', 'session', 'second'),
        clue('global', 'text', 'session', '', 'start')
      ]);
      expect(visibleIds(result, first)).assertEqual('global,source-first');
      expect(visibleIds(result, second)).assertEqual('bound-second,global,source-second');
    });

    it('separatesCombinationAndUnmigratedRowsWithoutHidingOrdinaryCompletionImages', 0, () => {
      const first: GameplayLevel = level('first');
      const image: GameplayClue = clue('image', 'image', 'session', '', 'session_completed');
      image.content.imageUrls = ['https://images.example/two.png', '', 'https://images.example/one.png'];
      const result: GameplaySnapshot = snapshot([first, level('second')], [
        clue('combination', 'text', 'session', '', 'session_completed'),
        clue('level-ending', 'text', 'session', 'first', 'session_completed'),
        clue('empty-image', 'image'), clue('letter', 'letter'), clue('video', 'video'), clue('link', 'link'), image
      ]);
      expect(visibleIds(result, first)).assertEqual('image,level-ending');
      expect(clueImageSources(image).join(',')).assertEqual('https://images.example/two.png,https://images.example/one.png');
      expect(clueTitle(image)).assertEqual('神谕影像');
      expect(clueTitle(result.clues[0])).assertEqual('古老密卷');
      result.detail.totalLevels = 1;
      result.levels = [first];
      expect(visibleIds(result, first)).assertEqual('combination,image,level-ending');
    });

    it('matchesWebSourcePositionDefinitionAndIdOrderWithoutMutatingTheSnapshot', 0, () => {
      const first: GameplayLevel = level('first');
      const question: GameplayClue = clue('question', 'text', 'question', 'first');
      const sameDefinitionLate: GameplayClue = clue('last');
      sameDefinitionLate.definitionId = 'same';
      sameDefinitionLate.position = 1;
      const sameDefinitionEarly: GameplayClue = clue('early');
      sameDefinitionEarly.definitionId = 'same';
      sameDefinitionEarly.position = 1;
      const byId: GameplayClue = clue('middle');
      byId.position = 1;
      const positionFirst: GameplayClue = clue('position');
      const result: GameplaySnapshot = snapshot([first], [
        question, sameDefinitionLate, byId, sameDefinitionEarly, positionFirst
      ]);
      expect(visibleIds(result, first)).assertEqual('position,middle,early,last,question');
      expect(result.clues.map((row: GameplayClue) => row.id).join(',')).assertEqual('question,last,middle,early,position');
    });

    it('preservesHighlightsAndLineBreaksButNeverTurnsLinkOrVideoIntoAnAction', 0, () => {
      const source: string = '起始\r\n[[重点]]\n{{ https://images.example/clue.png }}\n结尾' +
        '((查看说明||https://links.example/read))<<https://video.example/movie>>{{http://images.example/insecure.png}}';
      const parts: ClueTextPart[] = clueTextParts(source);
      expect(parts.length).assertEqual(3);
      expect(plainText(parts[0])).assertEqual('起始\n重点');
      expect(parts[0].spans.find((span: ClueSpan) => span.highlight)?.text).assertEqual('重点');
      expect(parts[1].image).assertEqual('https://images.example/clue.png');
      expect(plainText(parts[2])).assertEqual('结尾查看说明');
      const preview: ClueTextPart[] = clueTextParts(source, true);
      expect(preview.length).assertEqual(1);
      expect(preview[0].image).assertEqual('');
      expect(plainText(preview[0])).assertEqual('起始\n重点\n结尾查看说明');
    });

    it('removes only structural media line breaks and preserves authored blank lines', 0, () => {
      const source: string = '上文\r\n\r\n{{/clue.png}}\r\n\r\n下文';
      const parts: ClueTextPart[] = clueTextParts(source);
      expect(parts.length).assertEqual(3);
      expect(plainText(parts[0])).assertEqual('上文\n');
      expect(parts[1].image).assertEqual('/clue.png');
      expect(plainText(parts[2])).assertEqual('\n下文');
      expect(plainText(clueTextParts(source, true)[0])).assertEqual('上文\n\n\n下文');
    });

    it('retainsOnlyAuthorizedGlobalCompletionTextInStableOrder', 0, () => {
      const latest: GameplayClue = clue('latest', 'text', 'session', '', 'session_completed');
      latest.position = 2;
      const result: GameplaySnapshot = snapshot([level('one'), level('two')], [
        latest, clue('bound', 'text', 'session', 'two', 'session_completed'),
        clue('question', 'text', 'question', '', 'session_completed'),
        clue('image', 'image', 'session', '', 'session_completed'), clue('start'),
        clue('earlier', 'text', 'session', '', 'session_completed')
      ]);
      expect(combinationClues(result).length).assertEqual(0);
      result.detail.status = 'completed';
      expect(combinationClues(result).map((row: GameplayClue) => row.id).join(',')).assertEqual('earlier,latest');
      result.detail.totalLevels = 1;
      expect(combinationClues(result).length).assertEqual(0);
      result.detail.totalLevels = 2;
      result.detail.status = 'cancelled';
      expect(combinationClues(result).length).assertEqual(0);
    });

    it('usesExplicitCompletionEffectsIncludingEmptyBeforeFallingBackToNewGrants', 0, () => {
      const first: GameplayClue = clue('previously-granted', 'text', 'session', '', 'session_completed');
      const second: GameplayClue = clue('newly-granted', 'text', 'session', '', 'session_completed');
      second.position = 2;
      const previous: GameplaySnapshot = snapshot([level('one'), level('two', false)], [first]);
      const final: GameplaySnapshot = snapshot([level('one'), level('two')], [second, first, clue('ordinary')]);
      final.detail.status = 'completed';
      expect(completionCombinations(previous, final, []).length).assertEqual(0);
      expect(completionCombinations(previous, final, [effect('ordinary'), effect('unknown')]).length).assertEqual(0);
      expect(completionCombinations(previous, final, [effect(second.id), effect(first.id), effect(second.id)])
        .map((row: GameplayClue) => row.id).join(',')).assertEqual('previously-granted,newly-granted');
      expect(completionCombinations(previous, final, undefined)[0]?.id).assertEqual('newly-granted');
    });
  });
}
