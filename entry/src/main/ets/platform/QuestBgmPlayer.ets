import { url } from '@kit.ArkTS';
import { audio } from '@kit.AudioKit';
import { media } from '@kit.MediaKit';
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppEnvironment } from './AppEnvironment';

const WEB_ORIGIN: string = 'https://sitkin.top/';
const FIXTURE_ORIGIN: string = 'https://127.0.0.1:18443';
const MAX_TRACK_BYTES: number = 16 * 1024 * 1024;
const VOLUME: number = 0.3;

class BgmTarget {
  readonly href: string;
  readonly caData?: string;

  constructor(href: string, caData?: string) {
    this.href = href;
    this.caData = caData;
  }
}

function bgmTarget(source: string): BgmTarget | undefined {
  if (source.length === 0 || source.length > 8192 || /[\s\\\u0000-\u001f\u007f]/.test(source)) {
    return undefined;
  }
  if (AppEnvironment.endpoint === FIXTURE_ORIGIN && AppEnvironment.probeTls &&
    AppEnvironment.configurationError === '' && AppEnvironment.caData.length > 0 &&
    (source === FIXTURE_ORIGIN + '/starward-fixture/bgm/theme-a.mp3' ||
      source === FIXTURE_ORIGIN + '/starward-fixture/bgm/theme-b.mp3')) {
    return new BgmTarget(source, AppEnvironment.caData);
  }
  if ((!/^https:\/\//i.test(source) && (!source.startsWith('/') || source.startsWith('//'))) ||
    /^https:\/\/[^/?#]*@/i.test(source)) {
    return undefined;
  }
  try {
    const target: url.URL = url.URL.parseURL(source, WEB_ORIGIN);
    const host: string = target.hostname.toLowerCase().replace(/\.$/, '');
    if (target.protocol !== 'https:' || target.username.length > 0 || target.password.length > 0 ||
      (target.port.length > 0 && target.port !== '443') || host.length > 253 ||
      !/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(host) ||
      /\.[0-9]+$/.test(host) || /\.(localhost|local|localdomain|internal|lan|home|test|invalid|onion)$/.test(host) ||
      host === 'home.arpa' || host.endsWith('.home.arpa')) {
      return undefined;
    }
    target.hash = '';
    return new BgmTarget(target.href);
  } catch {
    return undefined;
  }
}

export function isQuestBgmSource(source: string): boolean {
  return bgmTarget(source) !== undefined;
}

export type QuestBgmState = 'idle' | 'loading' | 'playing' | 'paused' | 'error';

type BgmFocus = 'clear' | 'temporary' | 'manual';
type BgmCommand = '' | 'prepare' | 'play' | 'pause';

class BgmAttempt {
  readonly number: number;
  request?: http.HttpRequest;
  creation?: Promise<media.AVPlayer>;
  player?: media.AVPlayer;
  bytes?: Uint8Array;
  ready: boolean = false;
  command: BgmCommand = '';
  watchdog: number = -1;
  lastTime: number = -1;
  lastBucket: number = -1;

  constructor(number: number) { this.number = number; }

  cancelRequest(): void {
    const pending: http.HttpRequest | undefined = this.request;
    this.request = undefined;
    try { pending?.destroy(); } catch { /* An SDK error may contain the URL. */ }
  }

  read(buffer: ArrayBuffer, length: number, position?: number): number {
    const input: Uint8Array | undefined = this.bytes;
    const offset: number = position ?? 0;
    if (input === undefined || !Number.isSafeInteger(offset) || offset < 0 ||
      !Number.isSafeInteger(length) || length < 0) {
      return -2;
    }
    if (offset >= input.byteLength) { return -1; }
    const count: number = Math.min(length, buffer.byteLength, input.byteLength - offset);
    new Uint8Array(buffer).set(input.subarray(offset, offset + count));
    return count;
  }
}

/** Owns exactly one quest's foreground audio; UI preference remains separate from SDK state. */
export class QuestBgmPlayer {
  private readonly changed: (state: QuestBgmState) => void;
  private state: QuestBgmState = 'idle';
  private owner: string = '';
  private target?: BgmTarget;
  private foreground: boolean = false;
  private videoVisible: boolean = false;
  private wantsPlayback: boolean = false;
  private focus: BgmFocus = 'clear';
  private ducked: boolean = false;
  private failed: boolean = false;
  private attempt?: BgmAttempt;
  private nextAttempt: number = 0;
  private retired: Promise<boolean> = Promise.resolve(true);
  private quietWaiters: Array<(quiet: boolean) => void> = [];

  constructor(changed: (state: QuestBgmState) => void) { this.changed = changed; }

  update(owner: string, source: string, foreground: boolean, videoVisible: boolean, wantsPlayback: boolean): void {
    const target: BgmTarget | undefined = owner.length > 0 ? bgmTarget(source) : undefined;
    if (this.owner !== owner || this.target?.href !== target?.href) {
      this.retire();
      // A temporary interruption cannot signal RESUME on a destroyed audio stream.
      this.focus = this.owner === owner && this.focus !== 'clear' ? 'manual' : 'clear';
      this.ducked = false;
      this.failed = false;
      this.owner = owner;
      this.target = target;
    }
    this.foreground = foreground;
    this.videoVisible = videoVisible;
    this.wantsPlayback = wantsPlayback;
    this.reconcile();
  }

  retry(): void {
    if (this.target === undefined || !this.wantsPlayback || !this.foreground || this.videoVisible) {
      return;
    }
    // Some external media pauses never send RESUME. An explicit play lets the SDK request focus again.
    this.focus = 'clear';
    this.failed = false;
    this.reconcile();
  }

  release(): void {
    this.retire();
    this.owner = '';
    this.target = undefined;
    this.foreground = false;
    this.videoVisible = false;
    this.wantsPlayback = false;
    this.focus = 'clear';
    this.ducked = false;
    this.failed = false;
    this.publish('idle');
    this.flushQuietWaiters();
  }

  /** The video can prepare while music pauses; start it only after silence is confirmed. */
  whenQuiet(): Promise<boolean> {
    if (!this.videoVisible) { return Promise.resolve(false); }
    return new Promise<boolean>((resolve: (quiet: boolean) => void) => {
      const finish = (quiet: boolean): void => {
        clearTimeout(timer);
        this.quietWaiters = this.quietWaiters.filter((waiter: (quiet: boolean) => void) => waiter !== finish);
        resolve(quiet);
      };
      const timer: number = setTimeout(() => finish(false), 3500);
      this.quietWaiters.push(finish);
      this.flushQuietWaiters();
    });
  }

  private publish(state: QuestBgmState): void {
    if (this.state !== state) {
      this.state = state;
      this.changed(state);
    }
  }

  private canPlay(): boolean {
    return this.foreground && !this.videoVisible && this.wantsPlayback && this.focus === 'clear';
  }

  private live(attempt: BgmAttempt): boolean { return this.attempt === attempt; }

  private reconcile(): void {
    try { this.applyPolicy(); } finally { this.flushQuietWaiters(); }
  }

  private isAudibleOrStarting(): boolean {
    return this.attempt?.player?.state === 'playing' || this.attempt?.command === 'play';
  }

  private flushQuietWaiters(): void {
    if (this.quietWaiters.length === 0) { return; }
    if (!this.videoVisible) {
      this.quietWaiters.slice().forEach((finish: (quiet: boolean) => void) => finish(false));
    } else if (!this.isAudibleOrStarting()) {
      const retiring: Promise<boolean> = this.retired;
      retiring.then((quiet: boolean) => {
        if (retiring === this.retired && this.videoVisible && !this.isAudibleOrStarting()) {
          this.quietWaiters.slice().forEach((finish: (quiet: boolean) => void) => finish(quiet));
        }
      });
    }
  }

  private applyPolicy(): void {
    if (this.target === undefined) {
      this.publish('idle');
      return;
    }
    if (!this.foreground) {
      if (this.focus === 'temporary') { this.focus = 'manual'; }
      this.ducked = false;
      this.retire();
      this.publish(this.failed ? 'error' : 'paused');
      return;
    }
    if (this.failed) {
      this.publish('error');
      return;
    }
    const attempt: BgmAttempt | undefined = this.attempt;
    const player: media.AVPlayer | undefined = attempt?.player;
    if (attempt === undefined) {
      if (this.canPlay()) { this.start(this.target); } else { this.publish('paused'); }
      return;
    }
    if (player === undefined) {
      if (!this.canPlay()) { this.retire(); this.publish('paused'); }
      return;
    }
    const state: media.AVPlayerState = player.state;
    if (!this.canPlay()) {
      if (state === 'playing' && attempt.command === '') {
        this.run(attempt, player, 'pause');
      } else if (state !== 'playing' && attempt.command !== 'play') {
        this.publish('paused');
      }
      return;
    }
    if (state === 'playing') {
      this.publish('playing');
    } else if (attempt.ready && (state === 'prepared' || state === 'paused' || state === 'completed') &&
      attempt.command === '') {
      this.run(attempt, player, 'play');
    }
  }

  private async start(target: BgmTarget): Promise<void> {
    const attempt: BgmAttempt = new BgmAttempt(++this.nextAttempt);
    this.attempt = attempt;
    this.publish('loading');
    this.trace(attempt, 'begin');
    try {
      const request: http.HttpRequest = http.createHttp();
      attempt.request = request;
      let response: http.HttpResponse;
      try {
        request.enableAutoCookie(false);
        response = await request.request(target.href, {
          method: http.RequestMethod.GET,
          header: { 'Accept': 'audio/*,application/octet-stream;q=0.5', 'Referer': WEB_ORIGIN },
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          usingCache: false,
          usingProxy: false,
          maxRedirects: 0,
          maxLimit: MAX_TRACK_BYTES,
          connectTimeout: AppEnvironment.timeoutMs,
          readTimeout: AppEnvironment.timeoutMs,
          caData: target.caData,
          remoteValidation: 'system',
          enablePartialChain: false,
          reuseConnections: false
        });
      } finally {
        attempt.cancelRequest();
      }
      if (!this.live(attempt)) { return; }
      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer) ||
        response.result.byteLength === 0 || response.result.byteLength > MAX_TRACK_BYTES) {
        this.trace(attempt, 'http', response.responseCode);
        this.fail(attempt);
        return;
      }
      const drainOk: boolean = await this.retired;
      if (!this.live(attempt)) { return; }
      if (!drainOk) { this.fail(attempt); return; }
      attempt.bytes = new Uint8Array(response.result);
      attempt.watchdog = setTimeout(() => this.fail(attempt), 12000);
      attempt.creation = media.createAVPlayer();
      const player: media.AVPlayer = await attempt.creation;
      if (!this.live(attempt)) { return; }
      attempt.player = player;
      player.on('stateChange', (state: media.AVPlayerState) => this.nativeState(attempt, player, state));
      player.on('error', () => this.fail(attempt));
      player.on('audioInterrupt', (info: audio.InterruptEvent) => this.interrupt(attempt, player, info));
      player.on('audioOutputDeviceChangeWithInfo', (info: audio.AudioStreamDeviceChangeInfo) => {
        if (this.live(attempt) && info.changeReason === audio.AudioStreamDeviceChangeReason.REASON_OLD_DEVICE_UNAVAILABLE &&
          (player.state === 'playing' || attempt.command === 'play')) {
          this.focus = 'manual';
          this.reconcile();
        }
      });
      if (AppEnvironment.probeTls) {
        player.on('timeUpdate', (time: number) => this.position(attempt, player, time));
      }
      player.dataSrc = {
        fileSize: attempt.bytes.byteLength,
        callback: (buffer: ArrayBuffer, length: number, position?: number) => attempt.read(buffer, length, position)
      };
    } catch {
      this.fail(attempt);
    }
  }

  private nativeState(attempt: BgmAttempt, player: media.AVPlayer, state: media.AVPlayerState): void {
    if (!this.live(attempt)) { return; }
    this.trace(attempt, state);
    try {
      if (state === 'initialized') {
        player.audioRendererInfo = { usage: audio.StreamUsage.STREAM_USAGE_MUSIC, rendererFlags: 0 };
        this.run(attempt, player, 'prepare');
        return;
      }
      if (state === 'prepared') {
        clearTimeout(attempt.watchdog);
        attempt.watchdog = -1;
        player.audioInterruptMode = audio.InterruptMode.SHARE_MODE;
        player.loop = true;
        player.setVolume(VOLUME);
        attempt.ready = true;
        this.trace(attempt, 'duration', player.duration);
      } else if (state === 'stopped') {
        // No RESUME notification follows a forced stop; an explicit play action can re-arm it.
        this.focus = 'manual';
        this.retire();
        this.publish('paused');
        return;
      } else if (state === 'error' || state === 'released') {
        this.fail(attempt);
        return;
      }
      this.reconcile();
    } catch {
      this.fail(attempt);
    }
  }

  private async run(attempt: BgmAttempt, player: media.AVPlayer, command: BgmCommand): Promise<void> {
    attempt.command = command;
    try {
      if (command === 'prepare') {
        await player.prepare();
      } else if (command === 'play') {
        await player.play();
      } else {
        await player.pause();
      }
    } catch {
      if (this.live(attempt) && !(command === 'pause' && player.state === 'paused') &&
        !(command === 'play' && !this.canPlay())) {
        this.fail(attempt);
      }
    } finally {
      attempt.command = '';
      if (this.live(attempt) && (command !== 'prepare' || player.state === 'prepared') &&
        (command !== 'play' || player.state === 'playing' || !this.canPlay()) &&
        (command !== 'pause' || player.state !== 'playing' || this.canPlay())) {
        this.reconcile();
      }
    }
  }

  private interrupt(attempt: BgmAttempt, player: media.AVPlayer, info: audio.InterruptEvent): void {
    if (!this.live(attempt)) { return; }
    const hint: audio.InterruptHint = info.hintType;
    this.trace(attempt, 'focus', hint);
    if (hint === audio.InterruptHint.INTERRUPT_HINT_STOP) {
      this.focus = 'manual';
      this.retire();
      this.publish('paused');
    } else if (hint === audio.InterruptHint.INTERRUPT_HINT_PAUSE && this.focus !== 'manual') {
      this.focus = 'temporary';
      if (info.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
        // System audio can already be silent while AVPlayer still reports playing.
        this.publish('paused');
      }
      this.reconcile();
    } else if (hint === audio.InterruptHint.INTERRUPT_HINT_RESUME && this.focus === 'temporary') {
      this.focus = 'clear';
      this.reconcile();
    } else if ((hint === audio.InterruptHint.INTERRUPT_HINT_DUCK ||
      hint === audio.InterruptHint.INTERRUPT_HINT_UNDUCK) &&
      info.forceType === audio.InterruptForceType.INTERRUPT_SHARE &&
      (player.state === 'playing' || player.state === 'paused' || player.state === 'prepared')) {
      this.ducked = hint === audio.InterruptHint.INTERRUPT_HINT_DUCK;
      try { player.setVolume(this.ducked ? VOLUME * 0.2 : VOLUME); } catch { /* An advisory change is optional. */ }
    }
  }

  private position(attempt: BgmAttempt, player: media.AVPlayer, time: number): void {
    if (!this.live(attempt) || player.state !== 'playing' || !this.canPlay() || !Number.isFinite(time) || time < 0) {
      return;
    }
    if (attempt.lastTime - time > 500) { this.trace(attempt, 'loop', time); }
    attempt.lastTime = time;
    const bucket: number = Math.floor(time / 1000);
    if (bucket !== attempt.lastBucket) {
      attempt.lastBucket = bucket;
      this.trace(attempt, 'position', time);
    }
  }

  private fail(attempt: BgmAttempt): void {
    if (!this.live(attempt)) { return; }
    this.trace(attempt, 'error');
    this.failed = true;
    this.retire();
    this.publish('error');
  }

  private retire(): void {
    const attempt: BgmAttempt | undefined = this.attempt;
    if (attempt === undefined) { return; }
    this.attempt = undefined;
    attempt.cancelRequest();
    clearTimeout(attempt.watchdog);
    this.retired = this.retired.then(async (alreadyQuiet: boolean) => {
      let quiet: boolean = true;
      try {
        const player: media.AVPlayer | undefined = attempt.player ?? await attempt.creation;
        if (player !== undefined) { quiet = await this.dispose(player); }
      } catch {
        // Creation can reject before owning any native player.
        quiet = attempt.player === undefined;
      } finally {
        attempt.bytes = undefined;
        this.trace(attempt, quiet ? 'released' : 'releaseFailed');
      }
      return alreadyQuiet && quiet;
    });
    this.flushQuietWaiters();
  }

  private async dispose(player: media.AVPlayer): Promise<boolean> {
    try {
      if (player.state !== 'released') { await player.release(); }
      return true;
    } catch {
      // Never start a second track if the original could still be audible.
      try {
        if (player.state === 'playing') { await player.pause(); }
        return player.state === 'paused' || player.state === 'stopped' || player.state === 'released';
      } catch {
        return false;
      }
    }
  }

  private trace(attempt: BgmAttempt, event: string, value: number = 0): void {
    if (AppEnvironment.probeTls) {
      hilog.info(0x0000, 'StarwardBgm', 'attempt=%{public}d event=%{public}s value=%{public}d',
        attempt.number, event, value);
    }
  }
}
