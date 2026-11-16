import { hilog } from '@kit.PerformanceAnalysisKit';
import { NarrativeBless, NarrativeBlessLine } from '../business/NarrativeModels';
import { AppEnvironment } from '../platform/AppEnvironment';
import { QuestBgmPlayer, QuestBgmState } from '../platform/QuestBgmPlayer';

const OPENING_MS: number = 800;
const DISPERSE_MS: number = 1500;

/** Holds one visit's presentation time and foreground audio. */
@ObservedV2
export class BlessPlayback {
  @Trace started: boolean = false;
  @Trace phrase: string = '';
  @Trace creditsVisible: boolean = false;
  @Trace creditIndex: number = -1;
  @Trace musicState: QuestBgmState = 'idle';

  private readonly music: QuestBgmPlayer = new QuestBgmPlayer((state: QuestBgmState) => {
    this.musicState = state;
  }, 'bless-music');
  private readonly voice: QuestBgmPlayer = new QuestBgmPlayer((state: QuestBgmState) => {
    if (state === 'error' || (state === 'paused' && this.foreground)) { this.finishVoice(false); }
  }, 'bless-voice', () => this.finishVoice(true));
  private scene: NarrativeBless | null = null;
  private owner: string = '';
  private foreground: boolean = false;
  private wantsMusic: boolean = false;
  private voiceSource: string = '';
  private voiceFinished?: (ended: boolean) => void;
  private remaining: number = 0;
  private deadline: number = 0;
  private timer: number = -1;
  private timerAction?: () => void;

  start(scene: NarrativeBless, owner: string): void {
    if (this.started || !this.foreground || scene.phrases.length === 0) { return; }
    this.scene = scene;
    this.owner = owner;
    this.started = true;
    this.wantsMusic = scene.mainAudioUrl.length > 0;
    this.updateMusic();
    this.wait(OPENING_MS, () => this.showPhrase(0));
  }

  startCredits(): void {
    if (this.creditsVisible && this.creditIndex < 0 && this.foreground) { this.showCredit(0); }
  }

  toggleMusic(): void {
    if (!this.started || !this.foreground) { return; }
    this.wantsMusic = !this.wantsMusic || this.musicState === 'paused' || this.musicState === 'error';
    this.updateMusic();
    if (this.wantsMusic) { this.music.retry(); }
  }

  setForeground(foreground: boolean): void {
    if (this.foreground === foreground) { return; }
    this.foreground = foreground;
    if (!foreground && this.timer >= 0) {
      this.remaining = Math.max(0, this.deadline - Date.now());
      clearTimeout(this.timer);
      this.timer = -1;
    }
    this.updateMusic();
    if (this.voiceSource.length > 0) {
      this.voice.update(this.owner, this.voiceSource, foreground, false, true);
      if (foreground) { this.voice.retry(); }
    }
    if (foreground) { this.armTimer(); }
  }

  close(): void {
    this.scene = null;
    this.owner = '';
    this.foreground = false;
    clearTimeout(this.timer);
    this.timer = -1;
    this.timerAction = undefined;
    this.clearVoice();
    this.music.release();
  }

  private updateMusic(): void {
    const source: string = this.scene?.mainAudioUrl ?? '';
    if (source.length > 0) { this.music.update(this.owner, source, this.foreground, false, this.wantsMusic); }
  }

  private wait(duration: number, action: () => void): void {
    clearTimeout(this.timer);
    this.timer = -1;
    this.remaining = duration;
    this.timerAction = action;
    this.armTimer();
  }

  private armTimer(): void {
    const action: (() => void) | undefined = this.timerAction;
    if (!this.foreground || this.timer >= 0 || action === undefined) { return; }
    this.deadline = Date.now() + this.remaining;
    this.timer = setTimeout(() => {
      if (!this.foreground || this.timerAction !== action) { return; }
      this.timer = -1;
      this.timerAction = undefined;
      action();
    }, this.remaining);
  }

  private showPhrase(index: number): void {
    const scene: NarrativeBless | null = this.scene;
    if (scene === null) { return; }
    const line: NarrativeBlessLine = scene.phrases[index];
    this.phrase = line.text;
    this.trace('phrase', index);
    this.playVoice(line.audioUrl);
    this.wait(line.durationMs, () => {
      if (index < scene.phrases.length - 1) {
        this.phrase = '';
        this.trace('disperse', index);
        this.wait(DISPERSE_MS, () => this.showPhrase(index + 1));
      } else if (scene.closingLines.length > 0) {
        this.creditsVisible = true;
        this.trace('credits', 0);
        if (!scene.closingLines.some((credit: NarrativeBlessLine) => credit.audioUrl.length > 0)) {
          this.showCredit(0);
        }
      }
    });
  }

  private showCredit(index: number): void {
    const lines: NarrativeBlessLine[] = this.scene?.closingLines ?? [];
    if (index >= lines.length) { return; }
    this.creditIndex = index;
    this.trace('credit', index);
    const line: NarrativeBlessLine = lines[index];
    const advance = (): void => this.showCredit(index + 1);
    if (line.audioUrl.length === 0) {
      this.clearVoice();
      if (index < lines.length - 1) { this.wait(line.durationMs, advance); }
    } else {
      this.playVoice(line.audioUrl, (ended: boolean) => {
        if (index >= lines.length - 1) { return; }
        this.wait(ended ? 0 : line.durationMs, advance);
      });
    }
  }

  private playVoice(source: string, finished?: (ended: boolean) => void): void {
    this.clearVoice();
    if (source.length === 0) { return; }
    this.voiceSource = source;
    this.voiceFinished = finished;
    this.voice.update(this.owner, source, this.foreground, false, true);
  }

  private finishVoice(ended: boolean): void {
    const finished: ((ended: boolean) => void) | undefined = this.voiceFinished;
    this.clearVoice();
    finished?.(ended);
  }

  private clearVoice(): void {
    this.voiceSource = '';
    this.voiceFinished = undefined;
    this.voice.release();
  }

  private trace(phase: string, index: number): void {
    if (AppEnvironment.probeTls) {
      hilog.info(0x0000, 'StarwardBlessScene', 'phase:%{public}s index:%{public}d', phase, index);
    }
  }
}
