import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppEnvironment } from '../platform/AppEnvironment';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageFailure, QuestionImageLoader, QuestionImageResult } from '../platform/QuestionImageLoader';

class QuestBackgroundImage {
  readonly owner: string;
  readonly source: string;
  readonly image: QuestionImageResult;

  constructor(owner: string, source: string, image: QuestionImageResult) {
    this.owner = owner;
    this.source = source;
    this.image = image;
  }
}

/** Paints the authorized question's fixed, noninteractive background. */
@ComponentV2
export struct StarwardQuestBackground {
  @Require @Param source: string;
  @Require @Param ownerKey: string;
  @Require @Param sourceIsCurrent: (owner: string, source: string) => boolean;
  @Require @Param imageCache: QuestionImageCache;
  @Param retryRevision: number = 0;
  @Env(ReadonlyEnvKey.WINDOW_SIZE) windowSize: window.SizeInVP;
  @Local private visibleImage: QuestBackgroundImage | undefined = undefined;
  private readonly loader: QuestionImageLoader = new QuestionImageLoader();
  private revision: number = 0;
  private mounted: boolean = false;
  private failed: boolean = false;

  aboutToAppear(): void {
    this.mounted = true;
    this.load();
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.reset();
  }

  @Monitor('source', 'ownerKey', 'retryRevision')
  inputsChanged(changes: IMonitor): void {
    if (changes.dirty.includes('source') || changes.dirty.includes('ownerKey') || this.failed) {
      this.load();
    }
  }

  private reset(): void {
    this.revision++;
    this.loader.cancel();
    const previous: QuestBackgroundImage | undefined = this.visibleImage;
    this.visibleImage = undefined;
    this.failed = false;
    previous?.image.release();
  }

  private current(revision: number, owner: string, source: string): boolean {
    return this.mounted && this.revision === revision && owner === this.ownerKey && source === this.source &&
      this.sourceIsCurrent(owner, source);
  }

  private record(state: string, httpStatus: number = 0, cacheHit: boolean = false): void {
    if (AppEnvironment.endpoint.length > 0 && AppEnvironment.probeTls) {
      hilog.info(0x0000, 'StarwardQuestBackground', '%{public}s', JSON.stringify({ state, httpStatus, cacheHit }));
    }
  }

  private async load(): Promise<void> {
    this.reset();
    const revision: number = this.revision;
    const owner: string = this.ownerKey;
    const source: string = this.source;
    if (owner.length === 0 || source.length === 0 || !this.current(revision, owner, source)) { return; }
    const cached: QuestionImageResult | undefined = this.imageCache.acquire(source);
    if (cached !== undefined) {
      this.visibleImage = new QuestBackgroundImage(owner, source, cached);
      this.record('ready', 0, true);
      return;
    }
    const cacheVersion: number = this.imageCache.version();
    this.record('loading');
    try {
      const value: QuestionImageResult = await this.loader.load(source);
      if (!this.current(revision, owner, source)) {
        await value.release();
        return;
      }
      this.imageCache.remember(source, value, cacheVersion);
      this.visibleImage = new QuestBackgroundImage(owner, source, value);
      this.record('ready', 200);
    } catch (error) {
      if (this.current(revision, owner, source) && !(error instanceof QuestionImageFailure && error.cancelled)) {
        this.failed = true;
        this.record('failed', error instanceof QuestionImageFailure ? error.httpStatus : 0);
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.visibleImage !== undefined && this.visibleImage.source === this.source &&
        this.visibleImage.owner === this.ownerKey) {
        Stack() {
          Image(this.visibleImage.image.pixels).id('gameplay-background-image')
            .width('100%').height('100%').objectFit(ImageFit.Cover).draggable(false)
          Column().width('100%').height('100%')
            .linearGradient({ direction: GradientDirection.Bottom,
              colors: [[$r('app.color.quest_image_scrim_start'), 0], [$r('app.color.quest_image_scrim_end'), 1]] })
        }.width('100%').height(this.windowSize.height).renderGroup(true).opacity(0.3)
        Column().width('100%').height(180)
          .linearGradient({ direction: GradientDirection.Bottom,
            colors: [[$r('app.color.canvas'), 0], [$r('app.color.canvas'), 8 / 180],
              [$r('app.color.quest_image_fade_end'), 1]] })
      }
    }.width('100%').height('100%').clip(true)
      .accessibilityLevel('no-hide-descendants').hitTestBehavior(HitTestMode.None)
  }
}
