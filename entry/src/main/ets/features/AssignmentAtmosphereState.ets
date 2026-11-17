import { common } from '@kit.AbilityKit';
import { QuestBgmPosition } from '../business/QuestBgmDock';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { isQuestBgmSource, QuestBgmPlayer, QuestBgmState } from '../platform/QuestBgmPlayer';
import { QuestBgmPreference } from '../platform/QuestBgmPreference';

/** The same assignment destination owns the background and music before and after entry. */
@ObservedV2
export class AssignmentAtmosphereState {
  @Trace owner: string = '';
  @Trace background: string = '';
  @Trace backgroundRetryRevision: number = 0;
  @Trace trackAvailable: boolean = false;
  @Trace state: QuestBgmState = 'idle';
  @Trace position: QuestBgmPosition = new QuestBgmPosition();
  readonly imageCache: QuestionImageCache = new QuestionImageCache(() => this.owner);
  private readonly player: QuestBgmPlayer = new QuestBgmPlayer((state: QuestBgmState) => { this.state = state; });
  private context?: common.UIAbilityContext;
  private account: string = '';
  private source: string = '';
  private enabled: boolean = true;
  private foreground: boolean = false;
  private briefVideo: boolean = false;
  private gameplayVideo: boolean = false;

  owns(owner: string): boolean { return owner.length > 0 && owner === this.owner; }

  update(context: common.UIAbilityContext | undefined, owner: string, account: string, background: string,
    source: string, foreground: boolean): void {
    if (owner.length === 0 || account.length === 0) { this.release(); return; }
    if (owner !== this.owner) {
      this.briefVideo = false;
      this.gameplayVideo = false;
      this.owner = owner;
      this.imageCache.validateOwner();
    }
    this.context = context;
    if (this.account !== account) {
      this.account = account;
      this.enabled = context ? QuestBgmPreference.load(context, account) : true;
      this.position = context ? QuestBgmPreference.loadPosition(context, account) : new QuestBgmPosition();
    }
    this.background = background;
    this.source = isQuestBgmSource(source) ? source : '';
    this.trackAvailable = this.source.length > 0;
    if (foreground) {
      this.foreground = true;
      this.updatePlayer();
    } else {
      this.suspend();
    }
  }

  suspend(): void {
    if (this.foreground) { this.imageCache.clear(); }
    this.foreground = false;
    this.updatePlayer();
  }

  setVideo(owner: string, branch: 'briefing' | 'gameplay', open: boolean): void {
    if (!this.owns(owner)) { return; }
    if (branch === 'briefing') { this.briefVideo = open; } else { this.gameplayVideo = open; }
    this.updatePlayer();
  }

  whenQuiet(owner: string): Promise<boolean> {
    return this.owns(owner) ? this.player.whenQuiet() : Promise.resolve(false);
  }

  toggle(owner: string): void {
    if (!this.owns(owner) || !this.trackAvailable || this.briefVideo || this.gameplayVideo) { return; }
    this.enabled = this.state !== 'playing' && this.state !== 'loading';
    if (this.context) { QuestBgmPreference.save(this.context, this.account, this.enabled); }
    this.updatePlayer();
    if (this.enabled) { this.player.retry(); }
  }

  rememberPosition(owner: string, x: number, y: number): void {
    if (!this.owns(owner) || !this.trackAvailable || this.briefVideo || this.gameplayVideo) { return; }
    this.position = new QuestBgmPosition(x, y);
    if (this.context) { QuestBgmPreference.savePosition(this.context, this.account, this.position); }
  }

  retryBackground(owner: string): void {
    if (this.owns(owner)) { this.backgroundRetryRevision++; }
  }

  release(): void {
    if (this.owner.length === 0) { return; }
    this.player.release();
    this.owner = '';
    this.account = '';
    this.context = undefined;
    this.source = '';
    this.background = '';
    this.trackAvailable = false;
    this.foreground = false;
    this.briefVideo = false;
    this.gameplayVideo = false;
    this.imageCache.validateOwner();
  }

  private updatePlayer(): void {
    this.player.update(this.owner, this.source, this.foreground, this.briefVideo || this.gameplayVideo, this.enabled);
  }
}
