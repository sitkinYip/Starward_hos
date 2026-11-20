import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { avSession } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppEnvironment } from './AppEnvironment';

export interface QuestBgmBackgroundControls {
  play: () => void;
  pause: () => void;
  stop: () => void;
  interrupted: () => void;
}

export interface QuestBgmBackgroundSession {
  startTask(): Promise<number | undefined>;
  stopTask(taskId: number): Promise<void>;
  setPlaying(playing: boolean): Promise<void>;
  destroy(): Promise<void>;
}

export interface QuestBgmBackgroundIO {
  open(context: common.UIAbilityContext | undefined, controls: QuestBgmBackgroundControls,
    cancelled: (taskId: number) => void): Promise<QuestBgmBackgroundSession | undefined>;
}

/** All SDK objects stay here; business/account identifiers never enter system media metadata. */
class NativeBgmBackgroundSession implements QuestBgmBackgroundSession {
  private readonly context: common.UIAbilityContext;
  private readonly controls: QuestBgmBackgroundControls;
  private readonly cancelled: (taskId: number) => void;
  private session?: avSession.AVSession;
  private launch?: WantAgent;
  private artwork?: image.PixelMap;
  private taskId?: number;
  private startingTask: boolean = false;
  private cancelledDuringStart: number[] = [];
  private listening: boolean = false;
  private readonly cancelListener = (info: backgroundTaskManager.ContinuousTaskCancelInfo): void => {
    if (this.taskId === info.id) { this.taskId = undefined; }
    if (this.startingTask) { this.cancelledDuringStart.push(info.id); }
    this.cancelled(info.id);
  };

  constructor(context: common.UIAbilityContext, controls: QuestBgmBackgroundControls,
    cancelled: (taskId: number) => void) {
    this.context = context;
    this.controls = controls;
    this.cancelled = cancelled;
  }

  async prepare(): Promise<boolean> {
    try {
      const session: avSession.AVSession = await avSession.createAVSession(this.context, 'StarwardQuestBgm', 'audio');
      this.session = session;
      this.launch = await wantAgent.getWantAgent({
        wants: [{ bundleName: this.context.abilityInfo.bundleName, abilityName: this.context.abilityInfo.name }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 3101,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      });
      const bytes: Uint8Array = await this.context.resourceManager.getMediaContent($r('app.media.starward_icon').id);
      const source: image.ImageSource = image.createImageSource(bytes.buffer);
      try {
        this.artwork = await source.createPixelMap({ desiredSize: { width: 256, height: 256 } });
      } finally {
        await source.release();
      }
      await session.setAVMetadata({
        assetId: 'starward-quest-bgm', title: '赴星之约', subtitle: '答题背景音乐',
        artist: '赴星之约', mediaImage: this.artwork
      });
      session.on('play', this.controls.play);
      session.on('pause', this.controls.pause);
      session.on('stop', this.controls.stop);
      backgroundTaskManager.on('continuousTaskCancel', this.cancelListener);
      this.listening = true;
      await session.setLaunchAbility(this.launch);
      await session.setBackgroundPlayMode(avSession.BackgroundPlayMode.ENABLE_BACKGROUND_PLAY);
      await session.activate();
      this.trace('sessionReady', 1);
      return true;
    } catch (error) {
      await this.destroy();
      hilog.warn(0x0000, 'StarwardBgmBackground', 'Native background media session was not created code=%{public}d',
        (error as BusinessError).code ?? 0);
      return false;
    }
  }

  async startTask(): Promise<number | undefined> {
    if (this.taskId !== undefined) { return this.taskId; }
    if (this.session === undefined || this.launch === undefined) { return undefined; }
    this.startingTask = true;
    this.cancelledDuringStart = [];
    try {
      const request: backgroundTaskManager.ContinuousTaskRequest = new backgroundTaskManager.ContinuousTaskRequest();
      request.backgroundTaskModes = [backgroundTaskManager.BackgroundTaskMode.MODE_AUDIO_PLAYBACK];
      request.backgroundTaskSubmodes = [backgroundTaskManager.BackgroundTaskSubmode.SUBMODE_NORMAL_NOTIFICATION];
      request.wantAgent = this.launch;
      const result: backgroundTaskManager.ContinuousTaskNotification =
        await backgroundTaskManager.startBackgroundRunning(this.context, request);
      const grantedId: number | undefined = result.continuousTaskId;
      this.taskId = grantedId !== undefined && !this.cancelledDuringStart.includes(grantedId) ? grantedId : undefined;
      if (this.taskId === undefined) {
        // API 21 returns an ID. Do not leave a task unowned if the platform returns malformed data.
        if (grantedId === undefined) {
          await new Promise<void>((resolve: () => void, reject: (error: BusinessError) => void) => {
            backgroundTaskManager.stopBackgroundRunning(this.context, (error: BusinessError) => {
              if (error) { reject(error); } else { resolve(); }
            });
          });
        }
      }
      if (this.taskId !== undefined) { this.trace('taskStart', this.taskId); }
      return this.taskId;
    } catch (error) {
      hilog.warn(0x0000, 'StarwardBgmBackground', 'Native audio background task was not acquired code=%{public}d',
        (error as BusinessError).code ?? 0);
      return undefined;
    } finally {
      this.startingTask = false;
      this.cancelledDuringStart = [];
    }
  }

  async stopTask(taskId: number): Promise<void> {
    try {
      const stopped: Promise<void> = backgroundTaskManager.stopBackgroundRunning(this.context, taskId);
      await stopped;
      if (this.taskId === taskId) { this.taskId = undefined; }
      this.trace('taskStop', taskId);
    } catch (error) {
      hilog.warn(0x0000, 'StarwardBgmBackground', 'Native audio background task was not cancelled code=%{public}d',
        (error as BusinessError).code ?? 0);
    }
  }

  async setPlaying(playing: boolean): Promise<void> {
    try {
      await this.session?.setAVPlaybackState({
        state: playing ? avSession.PlaybackState.PLAYBACK_STATE_PLAY :
          avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
        loopMode: avSession.LoopMode.LOOP_MODE_SINGLE,
        speed: 1
      });
    } catch (error) {
      hilog.warn(0x0000, 'StarwardBgmBackground', 'Native media playback state was not updated code=%{public}d',
        (error as BusinessError).code ?? 0);
    }
  }

  async destroy(): Promise<void> {
    if (this.taskId !== undefined) { await this.stopTask(this.taskId); }
    if (this.listening) {
      try { backgroundTaskManager.off('continuousTaskCancel', this.cancelListener); } catch { /* Already removed. */ }
      this.listening = false;
    }
    const session: avSession.AVSession | undefined = this.session;
    this.session = undefined;
    if (session !== undefined) {
      try {
        await session.destroy();
        this.trace('released', 1);
      } catch (error) {
        hilog.warn(0x0000, 'StarwardBgmBackground', 'Native media session was not destroyed code=%{public}d',
          (error as BusinessError).code ?? 0);
      }
    }
    const artwork: image.PixelMap | undefined = this.artwork;
    this.artwork = undefined;
    try { await artwork?.release(); } catch { /* Native image was already released. */ }
    this.launch = undefined;
  }

  private trace(event: string, value: number): void {
    if (AppEnvironment.probeTls) {
      hilog.info(0x0000, 'StarwardBgmBackground', 'event=%{public}s value=%{public}d', event, value);
    }
  }
}

export class NativeQuestBgmBackgroundIO implements QuestBgmBackgroundIO {
  async open(context: common.UIAbilityContext | undefined, controls: QuestBgmBackgroundControls,
    cancelled: (taskId: number) => void): Promise<QuestBgmBackgroundSession | undefined> {
    if (context === undefined) { return undefined; }
    const session: NativeBgmBackgroundSession = new NativeBgmBackgroundSession(context, controls, cancelled);
    return await session.prepare() ? session : undefined;
  }
}
