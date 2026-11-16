import { describe, expect, it } from '@ohos/hypium';
import { NarrativeBless, NarrativeBlessLine } from '../main/ets/business/NarrativeModels';
import { BlessPlayback } from '../main/ets/ui/BlessPlayback';

function quietScene(): NarrativeBless {
  const scene: NarrativeBless = new NarrativeBless();
  const phrase: NarrativeBlessLine = new NarrativeBlessLine();
  phrase.text = '星光落下';
  phrase.durationMs = 0;
  const credit: NarrativeBlessLine = new NarrativeBlessLine();
  credit.text = '旅途再见';
  scene.phrases = [phrase];
  scene.closingLines = [credit];
  return scene;
}

function nextOpeningWindow(): Promise<void> {
  return new Promise<void>((resolve: () => void) => { setTimeout(resolve, 1000); });
}

export default function blessPlaybackTests(): void {
  describe('BlessPlayback', () => {
    it('holdsTheOpeningWhileBackgroundedAndKeepsTheLastPhraseForCredits', 0, async () => {
      const player: BlessPlayback = new BlessPlayback();
      player.setForeground(true);
      player.start(quietScene(), 'first-visit');
      player.setForeground(false);
      await nextOpeningWindow();
      expect(player.phrase).assertEqual('');
      expect(player.creditsVisible).assertFalse();
      player.setForeground(true);
      await nextOpeningWindow();
      expect(player.phrase).assertEqual('星光落下');
      expect(player.creditsVisible).assertTrue();
      expect(player.creditIndex).assertEqual(0);
      player.close();
    });

    it('closingClearsQueuedPlaybackEvenIfForegroundReturns', 0, async () => {
      const player: BlessPlayback = new BlessPlayback();
      player.setForeground(true);
      player.start(quietScene(), 'leaving-visit');
      player.close();
      player.setForeground(true);
      await nextOpeningWindow();
      expect(player.phrase).assertEqual('');
      expect(player.creditsVisible).assertFalse();
      expect(player.creditIndex).assertEqual(-1);
      expect(player.musicState).assertEqual('idle');
    });
  });
}
