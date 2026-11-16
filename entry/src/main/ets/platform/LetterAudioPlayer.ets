import { ForegroundAudioChannel, ForegroundAudioRole, QuestBgmPlayer, QuestBgmState } from './QuestBgmPlayer';

const MUSIC_VOLUME: number = 0.5;
const NARRATION_MUSIC_VOLUME: number = 0.18;

export type LetterMusicState = QuestBgmState;

export type CreateLetterAudioChannel =
  (changed: (state: QuestBgmState) => void, role: ForegroundAudioRole, ended?: () => void) => ForegroundAudioChannel;

function createChannel(changed: (state: QuestBgmState) => void, role: ForegroundAudioRole,
  ended?: () => void): ForegroundAudioChannel {
  return new QuestBgmPlayer(changed, role, ended);
}

/** Coordinates two foreground AVPlayers for the currently opened letter. */
export class LetterAudioPlayer {
  private readonly music: ForegroundAudioChannel;
  private readonly voice: ForegroundAudioChannel;
  private readonly changed: (state: LetterMusicState) => void;
  private musicState: LetterMusicState = 'idle';
  private owner: string = '';
  private foreground: boolean = false;
  private musicSource: string = '';
  private wantsMusic: boolean = false;
  private voiceSource: string = '';
  private voiceCompleted?: () => void;

  constructor(changed: (state: LetterMusicState) => void, makeChannel: CreateLetterAudioChannel = createChannel) {
    this.changed = changed;
    this.music = makeChannel((state: QuestBgmState) => this.publishMusic(state), 'letter-music');
    this.voice = makeChannel((state: QuestBgmState) => {
      if (state === 'error' || (state === 'paused' && this.foreground)) {
        this.finishVoice();
      }
    }, 'letter-voice', () => this.finishVoice());
  }

  open(owner: string, musicUrl: string, foreground: boolean): void {
    this.close();
    this.owner = owner;
    this.foreground = foreground;
    this.musicSource = musicUrl;
    this.wantsMusic = musicUrl.length > 0;
    this.updateMusic();
  }

  setForeground(foreground: boolean): void {
    if (this.foreground === foreground) { return; }
    this.foreground = foreground;
    this.updateMusic();
    if (this.voiceCompleted !== undefined) {
      this.voice.update(this.owner, this.voiceSource, foreground, false, true);
      if (foreground) {
        // A pause from the audio service may not send a separate RESUME event.
        this.voice.retry();
      }
    }
  }

  toggleMusic(): void {
    if (this.owner.length === 0 || !this.foreground || this.musicSource.length === 0) { return; }
    this.wantsMusic = !this.wantsMusic || this.musicState === 'paused' || this.musicState === 'error';
    this.updateMusic();
    if (this.wantsMusic) { this.music.retry(); }
  }

  playVoice(source: string, completed: () => void): void {
    this.clearVoice();
    if (this.owner.length === 0 || source.length === 0) {
      completed();
      return;
    }
    this.voiceSource = source;
    this.voiceCompleted = completed;
    this.music.setPlaybackVolume(NARRATION_MUSIC_VOLUME);
    this.voice.update(this.owner, source, this.foreground, false, true);
  }

  close(): void {
    this.owner = '';
    this.foreground = false;
    this.musicSource = '';
    this.wantsMusic = false;
    this.music.release();
    this.clearVoice();
    this.publishMusic('idle');
  }

  private updateMusic(): void {
    if (this.owner.length === 0 || this.musicSource.length === 0) { return; }
    this.music.update(this.owner, this.musicSource, this.foreground, false, this.wantsMusic);
  }

  private publishMusic(state: LetterMusicState): void {
    if (this.musicState === state) { return; }
    this.musicState = state;
    this.changed(state);
  }

  private finishVoice(): void {
    const completed: (() => void) | undefined = this.voiceCompleted;
    if (completed === undefined) { return; }
    this.clearVoice();
    completed();
  }

  private clearVoice(): void {
    this.voiceSource = '';
    this.voiceCompleted = undefined;
    this.voice.release();
    this.music.setPlaybackVolume(MUSIC_VOLUME);
  }
}
