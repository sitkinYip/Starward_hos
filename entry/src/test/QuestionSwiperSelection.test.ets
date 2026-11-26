import { describe, expect, it } from '@ohos/hypium';
import { QuestionSwiperSelection } from '../main/ets/ui/QuestionSwiperSelection';

export default function questionSwiperSelectionTests(): void {
  describe('QuestionSwiperSelection', () => {
    it('commitsOneAdjacentGestureWithoutRequestingACorrectiveJump', 0, () => {
      const selection: QuestionSwiperSelection = new QuestionSwiperSelection();
      expect(selection.reset(['one', 'two', 'three'], 'two')).assertEqual(1);
      expect(selection.followGesture(1, 3, 'two')).assertFalse();
      expect(selection.followGesture(1, 2, 'two')).assertTrue();
      expect(selection.observe(2, 'two', true)).assertEqual('three');
      expect(selection.observe(2, 'three', true)).assertEqual('');
      expect(selection.request('three')).assertEqual(-1);
    });

    it('serializesExternalMovesAndKeepsOnlyTheLatestOwnerSelection', 0, () => {
      const selection: QuestionSwiperSelection = new QuestionSwiperSelection();
      selection.reset(['one', 'two', 'three'], 'one');
      expect(selection.request('two')).assertEqual(1);
      expect(selection.isMoving()).assertTrue();
      expect(selection.followGesture(0, 1, 'one')).assertFalse();
      expect(selection.request('three')).assertEqual(-1);
      expect(selection.observe(1, 'three', true)).assertEqual('');
      expect(selection.request('three')).assertEqual(2);
      expect(selection.observe(2, 'three', true)).assertEqual('');
      expect(selection.request('three')).assertEqual(-1);
      expect(selection.displayedId()).assertEqual('three');
    });

    it('discardsGesturesWhenOwnerChangesOrReadableTopologyShifts', 0, () => {
      const selection: QuestionSwiperSelection = new QuestionSwiperSelection();
      selection.reset(['one', 'two', 'three'], 'two');
      expect(selection.followGesture(1, 0, 'two')).assertTrue();
      expect(selection.observe(0, 'three', true)).assertEqual('');
      expect(selection.request('three')).assertEqual(2);
      expect(selection.observe(2, 'three', true)).assertEqual('');
      expect(selection.followGesture(2, 1, 'three')).assertTrue();
      selection.updatePages(['zero', 'one', 'two', 'three']);
      expect(selection.observe(1, 'three', true)).assertEqual('');
      expect(selection.request('three')).assertEqual(3);
    });

    it('allowsAnAlreadyAuthorizedAdvanceWhenTheNextQuestionIsNewlyReadable', 0, () => {
      const selection: QuestionSwiperSelection = new QuestionSwiperSelection();
      selection.reset(['one'], 'one');
      expect(selection.followGesture(0, 1, 'one')).assertFalse();
      expect(selection.request('two')).assertEqual(-1);
      selection.updatePages(['one', 'two']);
      expect(selection.request('two')).assertEqual(1);
      expect(selection.observe(1, 'two', false)).assertEqual('');
      expect(selection.displayedId()).assertEqual('two');
    });

    it('ignoresAnOldAnimationEndWhileWaitingForTheCurrentDestination', 0, () => {
      const selection: QuestionSwiperSelection = new QuestionSwiperSelection();
      selection.reset(['one', 'two', 'three'], 'one');
      expect(selection.request('two')).assertEqual(1);
      selection.animationStarted(0, 1);
      expect(selection.observe(1, 'three', true)).assertEqual('');
      expect(selection.request('three')).assertEqual(2);
      expect(selection.animationEnded(2)).assertFalse();
      selection.animationStarted(1, 2);
      expect(selection.animationEnded(1)).assertFalse();
      expect(selection.awaits(2)).assertTrue();
      expect(selection.displayedId()).assertEqual('two');
      expect(selection.animationEnded(2)).assertTrue();
      expect(selection.displayedId()).assertEqual('three');
    });
  });
}
