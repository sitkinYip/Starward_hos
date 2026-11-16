import { describe, expect, it } from '@ohos/hypium';
import { LetterAudioPlayer } from '../main/ets/platform/LetterAudioPlayer';
import { ForegroundAudioChannel, ForegroundAudioRole, QuestBgmState } from '../main/ets/platform/QuestBgmPlayer';

const MUSIC: string = 'https://media.example/letter.mp3';
const VOICE: string = 'https://media.example/voice.mp3';

class FakeLetterChannel implements ForegroundAudioChannel {
  owner: string = '';
  source: string = '';
  foreground: boolean = false;
  wantsPlayback: boolean = false;
  volume: number = 0;
  restarts: number = 0;
  changed: (state: QuestBgmState) => void = () => {};
  ended: () => void = () => {};

  update(owner: string, source: string, foreground: boolean, _videoVisible: boolean, wantsPlayback: boolean): void {
    // The native adapter validates destinations. This fake only exercises the resulting playback states.
    if (source !== MUSIC && source !== VOICE) {
      this.changed('error');
      return;
    }
    this.owner = owner;
    this.source = source;
    this.foreground = foreground;
    this.wantsPlayback = wantsPlayback;
    this.changed(foreground && wantsPlayback ? 'loading' : 'paused');
  }

  setPlaybackVolume(volume: number): void { this.volume = volume; }
  retry(): void { this.restarts++; }
  release(): void {
    this.owner = '';
    this.foreground = false;
    this.wantsPlayback = false;
    this.changed('idle');
  }
}

class LetterAudioFixture {
  readonly music: FakeLetterChannel = new FakeLetterChannel();
  readonly voice: FakeLetterChannel = new FakeLetterChannel();
  readonly controller: LetterAudioPlayer;
  musicState: QuestBgmState = 'idle';

  constructor() {
    this.controller = new LetterAudioPlayer((state: QuestBgmState) => { this.musicState = state; },
      (changed: (state: QuestBgmState) => void, role: ForegroundAudioRole, ended?: () => void) => {
        const channel: FakeLetterChannel = role === 'letter-voice' ? this.voice : this.music;
        channel.changed = changed;
        channel.ended = ended ?? (() => {});
        return channel;
      });
  }
}

export default function letterAudioTests(): void {
  describe('LetterAudioPlayer', () => {
    it('startsOnlyOnOpenAndTogglesMusicWithoutStoppingVoice', 0, () => {
      const fixture: LetterAudioFixture = new LetterAudioFixture();
      expect(fixture.music.owner).assertEqual('');
      fixture.controller.open('first', MUSIC, true);
      expect(fixture.music.source).assertEqual(MUSIC);
      expect(fixture.music.volume).assertEqual(0.5);
      expect(fixture.music.wantsPlayback).assertEqual(true);
      fixture.music.changed('playing');
      fixture.controller.playVoice(VOICE, () => {});
      expect(fixture.music.volume).assertEqual(0.18);
      expect(fixture.voice.source).assertEqual(VOICE);
      fixture.controller.toggleMusic();
      expect(fixture.music.wantsPlayback).assertEqual(false);
      expect(fixture.voice.wantsPlayback).assertEqual(true);
      fixture.controller.toggleMusic();
      expect(fixture.music.wantsPlayback).assertEqual(true);
      expect(fixture.music.restarts).assertEqual(1);
      expect(fixture.music.volume).assertEqual(0.18);
    });

    it('restoresVolumeAndSettlesOnceForCompletionOrFailure', 0, () => {
      const fixture: LetterAudioFixture = new LetterAudioFixture();
      fixture.controller.open('first', MUSIC, true);
      let finished: number = 0;
      fixture.controller.playVoice(VOICE, () => { finished++; });
      expect(finished).assertEqual(0);
      fixture.voice.ended();
      expect(finished).assertEqual(1);
      expect(fixture.music.volume).assertEqual(0.5);
      fixture.controller.playVoice(VOICE, () => { finished++; });
      fixture.voice.changed('error');
      fixture.voice.ended();
      expect(finished).assertEqual(2);
      expect(fixture.music.volume).assertEqual(0.5);
    });

    it('holdsNarrationWhenBackgroundedAndDropsItOnClose', 0, () => {
      const fixture: LetterAudioFixture = new LetterAudioFixture();
      fixture.controller.open('first', MUSIC, true);
      let finished: number = 0;
      fixture.controller.playVoice(VOICE, () => { finished++; });
      fixture.controller.setForeground(false);
      expect(fixture.music.foreground).assertEqual(false);
      expect(fixture.voice.foreground).assertEqual(false);
      expect(finished).assertEqual(0);
      fixture.controller.setForeground(true);
      expect(fixture.voice.foreground).assertEqual(true);
      expect(fixture.voice.source).assertEqual(VOICE);
      expect(fixture.voice.restarts).assertEqual(1);
      fixture.controller.close();
      fixture.voice.ended();
      expect(fixture.music.owner).assertEqual('');
      expect(fixture.voice.owner).assertEqual('');
      expect(finished).assertEqual(0);
    });

    it('allowsUnvoicedReadingAndIgnoresUnapprovedSources', 0, () => {
      const fixture: LetterAudioFixture = new LetterAudioFixture();
      fixture.controller.open('first', '', true);
      let finished: number = 0;
      fixture.controller.playVoice('', () => { finished++; });
      fixture.controller.playVoice('https://127.0.0.1/private.mp3', () => { finished++; });
      expect(finished).assertEqual(2);
      expect(fixture.musicState).assertEqual('idle');
      expect(fixture.voice.owner).assertEqual('');
      fixture.controller.playVoice(VOICE, () => { finished++; });
      fixture.voice.changed('paused');
      expect(finished).assertEqual(3);
    });
  });
}
