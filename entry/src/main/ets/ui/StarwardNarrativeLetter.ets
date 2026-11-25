import { curves, LengthMetrics, MeasureUtils, UIUtils } from '@kit.ArkUI';
import { NarrativeLetter, NarrativeParagraph } from '../business/NarrativeModels';
import { LetterAudioPlayer, LetterMusicState } from '../platform/LetterAudioPlayer';
import { QuestionImageCache } from '../platform/QuestionImageCache';
import { QuestionImageLoader, QuestionImageResult } from '../platform/QuestionImageLoader';
import { LetterColumn, LetterSegment, letterPageForCursor, letterVerticalColumns,
  paginateLetterRuns } from './NarrativeLetterPagination';

const FONT = 17;
const LINE = 32.3;
const PARAGRAPH_GAP = 22.95;
const VERTICAL_COLUMN = 32.3;
const VERTICAL_LETTER = 19.04;
const VERTICAL_PARAGRAPH_GAP = 22;
const VERTICAL_CARET_WIDTH = 1.36;
const VERTICAL_CARET_HEIGHT = 17.85;
const TURN_MS = 920;

class LetterColors {
  readonly canvas: string;
  readonly paper: string;
  readonly edge: string;
  readonly frame: string;
  readonly ink: string;
  readonly subdued: string;
  readonly envelope: string;
  readonly flap: string;
  readonly fold: string;
  readonly envelopeInk: string;
  readonly envelopeMuted: string;
  readonly seal: string;
  readonly sealEdge: string;
  readonly sealInk: string;

  constructor(canvas: string, paper: string, edge: string, frame: string, ink: string, subdued: string,
    envelope: string, flap: string, fold: string, envelopeInk: string, envelopeMuted: string,
    seal: string, sealEdge: string, sealInk: string) {
    this.canvas = canvas;
    this.paper = paper;
    this.edge = edge;
    this.frame = frame;
    this.ink = ink;
    this.subdued = subdued;
    this.envelope = envelope;
    this.flap = flap;
    this.fold = fold;
    this.envelopeInk = envelopeInk;
    this.envelopeMuted = envelopeMuted;
    this.seal = seal;
    this.sealEdge = sealEdge;
    this.sealInk = sealInk;
  }
}

const MODERN = new LetterColors('#12130F', '#E7DFCC', '#A89B7E', '#94B49558', '#302D28', '#675F50',
  '#D6C8A8', '#E0D3B4', '#CBBB98', '#433C2E', '#756A56', '#763F35', '#94574B', '#E4C9A8');
const CLASSICAL = new LetterColors('#12130F', '#E4D2AA', '#AD9061', '#949D392F', '#352820', '#685443',
  '#B93931', '#C8453A', '#CBBB98', '#F0CF9E', '#1E120B', '#763F35', '#94574B', '#E4C9A8');
const MAGIC = new LetterColors('#070D0D', '#10211F', '#46756C', '#9461A99B', '#DCEBE5', '#A9C0B8',
  '#102B28', '#153A35', '#CBBB98', '#D6E8E1', '#89AFA6', '#23675D', '#6FB6AA', '#D6F3E9');

@ComponentV2
struct NarrativeLetterCurl {
  @Require @Param paper: string;
  @Require @Param horizontal: boolean;
  @Require @Param turnSign: number;
  @Require @Param sheetWidth: number;
  @Require @Param sheetHeight: number;
  @Local private curlOffset: number = 2.84;
  @Local private angle: number = 8;
  @Local private extent: number = 0.12;
  @Local private alpha: number = 0;

  private setFrame(offset: number, angle: number, extent: number, alpha: number): void {
    this.curlOffset = offset;
    this.angle = angle;
    this.extent = extent;
    this.alpha = alpha;
  }

  private play(): void {
    const curve = curves.cubicBezierCurve(0.18, 0.72, 0.2, 1);
    this.getUIContext().keyframeAnimateTo({ iterations: 1 }, [
      { duration: 129, curve: curve, event: () => UIUtils.applySync(() => this.setFrame(2.70, 24, 0.34, 0.62)) },
      { duration: 349, curve: curve, event: () => UIUtils.applySync(() => this.setFrame(1.08, 54, 0.96, 1)) },
      { duration: 258, curve: curve, event: () => UIUtils.applySync(() => this.setFrame(-0.34, 32, 0.56, 0.86)) },
      { duration: 184, curve: curve, event: () => UIUtils.applySync(() => this.setFrame(-1, 5, 0.10, 0)) },
    ]);
  }

  private travel(): number {
    return 0.26 * (this.horizontal ? this.sheetWidth : this.sheetHeight) *
      (this.turnSign > 0 ? this.curlOffset : 2 - this.curlOffset);
  }

  build() {
    Column()
      .id('narrative-letter-page-curl')
      .width(this.horizontal ? this.sheetWidth * 0.26 : this.sheetWidth)
      .height(this.horizontal ? this.sheetHeight : this.sheetHeight * 0.26)
      .position({ x: 0, y: 0 }).backgroundColor(this.paper)
      .borderRadius(this.horizontal ? 10 : 16)
      .linearGradient({
        direction: this.horizontal ?
          (this.turnSign > 0 ? GradientDirection.Right : GradientDirection.Left) :
          (this.turnSign > 0 ? GradientDirection.Bottom : GradientDirection.Top),
        colors: [['#61000000', 0], ['#38FFFFFF', 0.18], [Color.Transparent, 0.44],
          ['#52000000', 0.7], ['#6BFFFFFF', 0.88], [Color.Transparent, 1]]
      })
      .shadow({ radius: 12, color: '#38160F08', offsetX: this.horizontal ? -8 * this.turnSign : 0,
        offsetY: this.horizontal ? 0 : -8 * this.turnSign })
      .rotate({ x: this.horizontal ? 0 : 1, y: this.horizontal ? 1 : 0, perspective: 900,
        angle: this.angle * this.turnSign * (this.horizontal ? -1 : 1) })
      .scale({ x: this.horizontal ? this.extent : 1, y: this.horizontal ? 1 : this.extent })
      .translate({ x: this.horizontal ? this.travel() : 0, y: this.horizontal ? 0 : this.travel() })
      .opacity(this.alpha).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      .onAppear(() => this.play())
  }
}

@ComponentV2
struct NarrativeLetterControl {
  @Require @Param controlId: string;
  @Require @Param label: string;
  @Param available: boolean = true;
  @Param strokeTint: string = '#746746';
  @Param isReturn: boolean = false;
  @Event action: () => void = () => {};

  build() {
    Button(this.label, { type: ButtonType.Normal }).id(this.controlId).constraintSize({ minHeight: 44 })
      .padding({ left: this.isReturn ? 14 : 16, right: this.isReturn ? 14 : 16 })
      .borderRadius(0).backgroundColor(this.isReturn ? '#D111120F' : Color.Transparent)
      .fontSize(16).fontColor(this.isReturn ? '#B7B5AC' : '#DED9CE')
      .border({ width: 1, color: this.isReturn ? '#3E4039' : this.strokeTint })
      .enabled(this.available).opacity(this.available ? 1 : 0.46).onClick(() => this.action())
  }
}

@ComponentV2
struct NarrativeMusicPulse {
  @Local private expanded: boolean = false;

  build() {
    Circle().width(48).height(48).fill('#146AA294')
      .scale({ x: this.expanded ? 1.375 : 1, y: this.expanded ? 1.375 : 1 })
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      .onAppear(() => {
        this.getUIContext().animateTo({ duration: 900, iterations: -1, playMode: PlayMode.Alternate,
          curve: curves.cubicBezierCurve(0.2, 0.68, 0.22, 1) }, () =>
          UIUtils.applySync(() => { this.expanded = true; }));
      })
  }
}

/** Read-only use of the existing image transport and shared route-local cache. */
@ComponentV2
struct NarrativeLetterImage {
  @Require @Param source: string;
  @Require @Param ownerKey: string;
  @Require @Param imageCache: QuestionImageCache;
  @Param reducedMotion: boolean = true;
  @Param imageOpacity: number = 1;
  @Param atmosphere: boolean = false;
  @Local private image: QuestionImageResult | undefined = undefined;
  private loadedSource: string = '';
  private loadedOwner: string = '';
  private mounted: boolean = false;
  private revision: number = 0;
  private readonly loader = new QuestionImageLoader();

  aboutToAppear(): void {
    this.mounted = true;
    this.load();
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.reset();
  }

  @Monitor('source', 'ownerKey')
  inputsChanged(): void { this.load(); }

  private replace(image: QuestionImageResult | undefined, owner: string, source: string): void {
    const previous: QuestionImageResult | undefined = this.image;
    this.image = image;
    this.loadedOwner = owner;
    this.loadedSource = source;
    previous?.release();
  }

  private reset(): void {
    this.revision++;
    this.loader.cancel();
    this.replace(undefined, '', '');
  }

  private async load(): Promise<void> {
    const owner: string = this.ownerKey;
    const source: string = this.source;
    if (!this.mounted || owner.length === 0 || source.length === 0) { this.reset(); return; }
    if (owner !== this.loadedOwner) { this.replace(undefined, owner, ''); }
    const revision: number = ++this.revision;
    this.loader.cancel();
    if (source === this.loadedSource) { return; }
    const cached: QuestionImageResult | undefined = this.imageCache.acquire(source);
    if (cached !== undefined) {
      this.replace(cached, owner, source);
      return;
    }
    const cacheRevision: number = this.imageCache.version();
    try {
      const image: QuestionImageResult = await this.loader.load(source);
      if (!this.mounted || this.revision !== revision || owner !== this.ownerKey || source !== this.source) {
        await image.release();
        return;
      }
      this.imageCache.remember(source, image, cacheRevision);
      this.replace(image, owner, source);
    } catch {
      // An optional atmosphere image can fail without blocking the letter.
    }
  }

  build() {
    Stack() {
      if (this.image !== undefined && this.loadedOwner === this.ownerKey && this.ownerKey.length > 0) {
        Image(this.image.pixels).width('100%').height('100%')
          .objectFit(ImageFit.Cover).draggable(false).opacity(this.imageOpacity)
          .blur(this.atmosphere ? 8 : 0)
          .scale({ x: this.atmosphere ? 1.05 : 1, y: this.atmosphere ? 1.05 : 1 })
          .transition(this.reducedMotion ? TransitionEffect.IDENTITY :
            TransitionEffect.opacity(0).animation({ duration: 600, curve: Curve.EaseOut }))
      }
    }.width('100%').height('100%').hitTestBehavior(HitTestMode.None).accessibilityLevel('no-hide-descendants')
  }
}

/** Mobile design of the frozen Web letter, using native text, shapes, gestures and transitions. */
@ComponentV2
export struct StarwardNarrativeLetter {
  @Require @Param letter: NarrativeLetter;
  @Require @Param ownerKey: string;
  @Param title: string = '';
  @Param displayFont: string = 'serif';
  @Param reducedMotion: boolean = true;
  @Param foreground: boolean = true;
  @Param topInset: number = 0;
  @Param bottomInset: number = 0;
  @Event returnToQuest: () => void = () => {};
  @Local private opened: boolean = false;
  @Local private finished: boolean = false;
  @Local private pageIndex: number = 0;
  @Local private previousPage: number = -1;
  @Local private turnDirection: number = 1;
  @Local private turnMotion: boolean = false;
  @Local private paragraphIndex: number = -1;
  @Local private visibleCharacters: number = 0;
  @Local private caretVisible: boolean = true;
  @Local private backgroundIndex: number = 0;
  @Local private musicState: LetterMusicState = 'idle';
  @Local private sceneWidth: number = 388;
  @Local private bodyWidth: number = 0;
  @Local private bodyHeight: number = 0;
  @Local private paperWidth: number = 0;
  @Local private paperHeight: number = 0;
  @Local private pages: LetterSegment[][] = [];
  private characterRuns: string[][] = [];
  private typingTimer: number = -1;
  private turningTimer: number = -1;
  private backgroundTimer: number = -1;
  private caretTimer: number = -1;
  private voicePending: boolean = false;
  private readonly audio = new LetterAudioPlayer((state: LetterMusicState) => { this.musicState = state; });
  private readonly imageCache = new QuestionImageCache(() => this.assetOwner());

  aboutToAppear(): void { this.prepareLetter(); }

  aboutToDisappear(): void {
    this.stopTimers();
    this.audio.close();
    this.voicePending = false;
    this.imageCache.clear();
  }

  @Monitor('ownerKey', 'letter')
  letterChanged(): void {
    this.close();
    this.imageCache.validateOwner();
  }

  @Monitor('foreground')
  foregroundChanged(): void {
    this.imageCache.validateOwner();
    this.audio.setForeground(this.foreground);
    if (this.foreground) {
      this.scheduleTyping();
      this.scheduleBackground();
    } else {
      this.stopTimers();
      this.previousPage = -1;
      this.turnMotion = false;
    }
  }

  @Monitor('reducedMotion')
  motionChanged(): void {
    if (this.reducedMotion) {
      clearTimeout(this.turningTimer);
      this.turningTimer = -1;
      this.previousPage = -1;
      this.turnMotion = false;
      this.scheduleTyping();
    }
  }

  @Monitor('displayFont')
  textLayoutChanged(): void { this.repaginate(); }

  @Monitor('opened', 'finished', 'foreground', 'reducedMotion')
  syncCaret(): void {
    if (!this.opened || this.finished || !this.foreground || this.reducedMotion) {
      clearInterval(this.caretTimer);
      this.caretTimer = -1;
      this.caretVisible = true;
    } else if (this.caretTimer === -1) {
      // Preserve the inline caret width when the 900 ms blink hides its ink.
      this.caretTimer = setInterval(() => { this.caretVisible = !this.caretVisible; }, 450);
    }
  }

  private colors(): LetterColors {
    if (this.letter.variant === 'classical') { return CLASSICAL; }
    return this.letter.variant === 'magic' ? MAGIC : MODERN;
  }

  private classical(): boolean { return this.letter.variant === 'classical'; }

  private assetOwner(): string { return this.foreground ? this.ownerKey : ''; }

  private stopTimers(): void {
    clearTimeout(this.typingTimer);
    clearTimeout(this.turningTimer);
    clearInterval(this.backgroundTimer);
    clearInterval(this.caretTimer);
    this.typingTimer = -1;
    this.turningTimer = -1;
    this.backgroundTimer = -1;
    this.caretTimer = -1;
  }

  private prepareLetter(): void {
    this.characterRuns = this.letter.paragraphs.map((paragraph: NarrativeParagraph) => Array.from(paragraph.content));
    this.pages = [this.characterRuns.map((characters: string[], index: number) =>
      new LetterSegment(index, 0, characters.length))];
  }

  private open(): void {
    if (!this.foreground || this.ownerKey.length === 0 || this.opened) { return; }
    this.opened = true;
    this.audio.open(this.ownerKey, this.letter.mainAudioUrl, this.foreground);
    this.scheduleBackground();
  }

  private close(): void {
    this.opened = false;
    this.stopTimers();
    this.audio.close();
    this.voicePending = false;
    this.pageIndex = 0;
    this.previousPage = -1;
    this.turnMotion = false;
    this.paragraphIndex = -1;
    this.visibleCharacters = 0;
    this.backgroundIndex = 0;
    this.finished = false;
    this.bodyWidth = 0;
    this.bodyHeight = 0;
    this.prepareLetter();
  }

  private scheduleBackground(): void {
    if (!this.opened || !this.foreground || this.letter.backgroundImages.length < 2 ||
      this.backgroundTimer !== -1) { return; }
    this.backgroundTimer = setInterval(() => {
      if (this.opened && this.foreground && this.letter.backgroundImages.length > 1) {
        this.backgroundIndex = (this.backgroundIndex + 1) % this.letter.backgroundImages.length;
      }
    }, 5000);
  }

  private paperImage(): string {
    return this.letter.backgroundImages[this.backgroundIndex] || this.letter.pageBackgroundUrl;
  }

  private scheduleTyping(): void {
    if (!this.opened || this.bodyWidth <= 0 || this.bodyHeight <= 0 || !this.foreground || this.finished ||
      this.previousPage >= 0 || this.typingTimer !== -1) { return; }
    const currentChars: string[] | undefined = this.characterRuns[this.paragraphIndex];
    const typing: boolean = currentChars !== undefined && this.visibleCharacters < currentChars.length;
    if (!typing && this.voicePending) { return; }
    const nextParagraph: NarrativeParagraph | undefined = this.letter.paragraphs[this.paragraphIndex + 1];
    const duration: number = typing ? this.letter.typingSpeedMs : (nextParagraph?.delayMs ?? 0);
    this.typingTimer = setTimeout(() => {
      this.typingTimer = -1;
      if (!this.opened || !this.foreground || this.finished || this.previousPage >= 0) { return; }
      if (typing) {
        this.visibleCharacters++;
      } else if (nextParagraph !== undefined) {
        this.paragraphIndex++;
        this.visibleCharacters = 0;
        this.startVoice(nextParagraph.audioUrl);
      } else {
        this.finished = true;
      }
      if (!this.finished) {
        const active: number = this.activePage();
        if (active > this.pageIndex) { this.turn(active); }
        this.scheduleTyping();
      }
    }, duration);
  }

  private startVoice(source: string): void {
    if (source.length === 0) { return; }
    this.voicePending = true;
    this.audio.playVoice(source, () => {
      this.voicePending = false;
      this.scheduleTyping();
    });
  }

  private skipTyping(): void {
    clearTimeout(this.typingTimer);
    this.typingTimer = -1;
    this.finished = true;
  }

  private activePage(): number {
    return letterPageForCursor(this.pages, this.paragraphIndex, this.visibleCharacters);
  }

  private canTurn(): boolean {
    return this.finished && this.pages.length > 1 && this.previousPage < 0 && this.foreground;
  }

  private manualTurn(direction: number): void {
    if (this.canTurn()) { this.turn(this.pageIndex + direction); }
  }

  private turn(index: number): void {
    if (index < 0 || index >= this.pages.length || index === this.pageIndex) { return; }
    const from: number = this.pageIndex;
    this.pageIndex = index;
    if (this.reducedMotion) { return; }
    this.turnDirection = index > from ? 1 : -1;
    this.previousPage = from;
    this.turnMotion = false;
    this.turningTimer = setTimeout(() => {
      this.turningTimer = -1;
      this.previousPage = -1;
      this.turnMotion = false;
      this.scheduleTyping();
    }, TURN_MS);
  }

  private startTurnMotion(): void {
    this.getUIContext().animateTo({ duration: TURN_MS, curve: curves.cubicBezierCurve(0.2, 0.68, 0.22, 1) },
      () => { this.turnMotion = true; });
  }

  private finishSwipe(event: GestureEvent): void {
    const primary: number = this.classical() ? event.offsetX : event.offsetY;
    const cross: number = this.classical() ? event.offsetY : event.offsetX;
    const threshold: number = Math.min(96, Math.max(48, (this.classical() ? this.paperWidth : this.paperHeight) * 0.12));
    if (Math.abs(primary) >= threshold && Math.abs(primary) > Math.abs(cross) * 1.15) {
      this.manualTurn(primary < 0 ? 1 : -1);
    }
  }

  private visibleText(segment: LetterSegment): string {
    const characters: string[] = this.characterRuns[segment.paragraph] ?? [];
    const end: number = this.finished || segment.paragraph < this.paragraphIndex ? segment.end :
      segment.paragraph === this.paragraphIndex ? Math.min(segment.end, this.visibleCharacters) : segment.start;
    return characters.slice(segment.start, Math.max(segment.start, end)).join('');
  }

  private showCursor(segment: LetterSegment): boolean {
    return !this.finished && segment.paragraph === this.paragraphIndex &&
      this.visibleCharacters >= segment.start && this.visibleCharacters <= segment.end;
  }

  private displayAlign(segment: LetterSegment): TextAlign {
    const alignment = this.letter.paragraphs[segment.paragraph]?.align;
    if (alignment === 'center') { return TextAlign.Center; }
    return alignment === 'right' || alignment === 'bottom' ? TextAlign.End : TextAlign.Start;
  }

  private fontVp(value: number): number {
    const context = this.getUIContext();
    return context.px2vp(context.fp2px(value));
  }

  private verticalColumns(content: string, caret: boolean = false): LetterColumn[] {
    return letterVerticalColumns(content, this.bodyHeight, this.fontVp(VERTICAL_LETTER),
      this.fontVp(VERTICAL_CARET_HEIGHT), caret);
  }

  private measure(utility: MeasureUtils, segment: LetterSegment): number {
    const content: string = this.characterRuns[segment.paragraph].slice(segment.start, segment.end).join('');
    if (this.classical()) { return this.verticalColumns(content).length * this.fontVp(VERTICAL_COLUMN); }
    const size = utility.measureTextSize({ textContent: content || '田', constraintWidth: this.bodyWidth,
      fontSize: FONT, lineHeight: LINE, fontFamily: this.displayFont, wordBreak: WordBreak.BREAK_WORD });
    const height: number = Number(size?.height);
    return Number.isFinite(height) && height > 0 ? this.getUIContext().px2vp(height) : this.fontVp(LINE);
  }

  private repaginate(): void {
    if (!this.opened || this.bodyWidth <= 0 || this.bodyHeight <= 0) { return; }
    const utility: MeasureUtils = this.getUIContext().getMeasureUtils();
    const limit: number = this.classical() ? this.bodyWidth : this.bodyHeight;
    const gap: number = this.classical() ? VERTICAL_PARAGRAPH_GAP : this.fontVp(PARAGRAPH_GAP);
    const pages: LetterSegment[][] = paginateLetterRuns(this.characterRuns, limit, gap,
      (segment: LetterSegment) => this.measure(utility, segment));
    this.pages = pages;
    this.pageIndex = this.finished ? Math.min(this.pageIndex, pages.length - 1) : Math.max(0, this.activePage());
    this.scheduleTyping();
  }

  private bodyChanged(area: Area): void {
    const width: number = Number(area.width);
    const height: number = Number(area.height);
    if (width <= 0 || height <= 0 || !Number.isFinite(width) || !Number.isFinite(height) ||
      (Math.abs(this.bodyWidth - width) < 0.5 && Math.abs(this.bodyHeight - height) < 0.5)) { return; }
    this.bodyWidth = width;
    this.bodyHeight = height;
    this.repaginate();
  }

  private envelopeWidth(): number { return Math.min(580, Math.max(160, this.sceneWidth - 42)); }

  private envelopeHeight(): number { return this.envelopeWidth() / (this.classical() ? 1.9 : 1.58); }

  private sealCharacter(): string {
    return Array.from(this.title || this.letter.hintText)[0] || '✦';
  }

  private envelopeCaptionShadow(title: boolean = false): ShadowOptions {
    let color: ResourceColor = Color.Transparent;
    if (this.letter.variant === 'magic') { color = title ? '#EF081411' : '#E9D6C8A8'; }
    if (this.classical()) { color = title ? '#E944231E' : '#90D6C8A8'; }
    return { color: color, radius: title ? 3 : 2.4, offsetY: title ? 1 : 0 };
  }

  private controlOutline(panel: boolean = false): string {
    if (this.classical()) { return panel ? '#5A382F' : '#6F4239'; }
    if (this.letter.variant === 'magic') { return panel ? '#455E54' : '#53766C'; }
    return panel ? '#615841' : '#746746';
  }

  private envelopeTransition(): TransitionEffect {
    return this.reducedMotion ? TransitionEffect.IDENTITY : TransitionEffect.asymmetric(
      TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 28 }))
        .combine(TransitionEffect.rotate({ angle: -1.5 }))
        .animation({ duration: 700, curve: curves.cubicBezierCurve(0.2, 0.75, 0.25, 1) }),
      TransitionEffect.IDENTITY);
  }

  private readerTransition(): TransitionEffect {
    return this.reducedMotion ? TransitionEffect.IDENTITY : TransitionEffect.asymmetric(
      TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 42 }))
        .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
        .animation({ duration: 650, curve: curves.cubicBezierCurve(0.18, 0.8, 0.25, 1) }),
      TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 20 }))
        .combine(TransitionEffect.scale({ x: 0.97, y: 0.97 }))
        .animation({ duration: 240, curve: Curve.EaseIn }));
  }

  @Builder
  private envelope() {
    Button({ type: ButtonType.Normal }) {
      Stack() {
        Polygon({ width: this.envelopeWidth(), height: this.envelopeHeight() * 0.66 })
          .points([[0, this.envelopeHeight() * 0.66], [this.envelopeWidth() / 2, this.envelopeHeight() * 0.17],
            [this.envelopeWidth(), this.envelopeHeight() * 0.66]])
          .fill(this.colors().fold).position({ x: 0, y: this.envelopeHeight() * 0.34 }).hitTestBehavior(HitTestMode.None)
        Polygon({ width: this.envelopeWidth(), height: this.envelopeHeight() * 0.58 })
          .points([[0, 0], [this.envelopeWidth(), 0], [this.envelopeWidth() / 2, this.envelopeHeight() * 0.58]])
          .fill(this.colors().flap).position({ x: 0, y: 0 }).hitTestBehavior(HitTestMode.None)
        Column({ space: 7 }) {
          Stack() {
            Column().width(104).height(104).borderRadius(52).radialGradient({ center: ['50%', '50%'], radius: 52,
              colors: [[this.letter.variant === 'magic' ? '#6B59BEAB' : '#5946241E', 0.53],
                [Color.Transparent, 1]] }).position({ x: -16, y: -16 }).hitTestBehavior(HitTestMode.None)
            Circle({ width: 72, height: 72 }).fill(this.colors().seal).stroke(this.colors().sealEdge).strokeWidth(2)
            Circle({ width: 64, height: 64 }).fill(Color.Transparent).stroke(this.colors().sealEdge).strokeWidth(1)
            Text(this.sealCharacter()).fontFamily(this.displayFont).fontSize(28).fontColor(this.colors().sealInk)
          }.width(72).height(72).margin({ bottom: 8 }).accessibilityLevel('no-hide-descendants')
          Text(this.title || '一封未署名的来信').fontFamily(this.displayFont).fontSize(22)
            .fontColor(this.letter.variant === 'magic' ? '#F0FAF4' : this.colors().envelopeInk)
            .textShadow(this.envelopeCaptionShadow(true))
            .textAlign(TextAlign.Center).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.letter.description.length > 0) {
            Text(this.letter.description).fontSize(13).textAlign(TextAlign.Center)
              .fontColor(this.letter.variant === 'magic' ? '#183A34' : this.colors().envelopeMuted)
              .textShadow(this.envelopeCaptionShadow())
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.width('100%').padding({ left: 20, right: 20, bottom: 11 })
        Text(this.letter.hintText).fontSize(11).fontFamily('monospace')
          .fontColor(this.letter.variant === 'magic' ? '#183A34' : this.colors().envelopeMuted)
          .textShadow(this.envelopeCaptionShadow())
          .letterSpacing('0.88fp').position({ right: 20, bottom: 17 })
      }.width('100%').height('100%')
    }.id('narrative-letter-open').width(this.envelopeWidth()).height(this.envelopeHeight()).padding(0)
      .borderRadius(0).backgroundColor(this.colors().envelope)
      .border({ width: 1, color: this.classical() ? '#D9AF76' : this.letter.variant === 'magic' ? '#4D8D82' : '#958568' })
      .shadow({ radius: 54, offsetY: 20, color: '#7A000000' }).clip(true)
      .accessibilityText(this.title || '一封未署名的来信').accessibilityDescription(this.letter.hintText)
      .onClick(() => this.open()).transition(this.envelopeTransition())
  }

  @Builder
  private paperHeader() {
    Column() {
      Text(this.letter.variant.toUpperCase() + ' LETTER').fontSize(12).fontFamily('monospace')
        .fontWeight(600).lineHeight('14.4fp').letterSpacing('1.68fp')
        .fontColor(this.letter.variant === 'magic' ? $r('app.color.narrative_magic_eyebrow') :
          $r('app.color.narrative_warm_eyebrow'))
      if (this.title.length > 0) {
        Text(this.title).id('narrative-letter-title').fontFamily(this.displayFont).fontWeight(500)
          .fontSize(32).lineHeight('32fp').letterSpacing('-1.12fp').fontColor(this.colors().ink)
          .lineBreakStrategy(LineBreakStrategy.BALANCED).margin({ top: 12 }).maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      if (this.letter.description.length > 0) {
        Text(this.letter.description).fontSize(16).lineHeight('24fp').fontColor(this.colors().subdued)
          .margin({ top: 12 }).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }.width('100%').alignItems(HorizontalAlign.Start).padding({ bottom: 26 })
      .borderWidth({ bottom: 1 }).borderColor(this.letter.variant === 'magic' ? '#337FBCAF' : '#2E413829')
  }

  @Builder
  private horizontalParagraph(segment: LetterSegment, current: boolean) {
    Text() {
      Span(this.visibleText(segment))
      if (current && this.showCursor(segment)) {
        Span('▏').fontColor(this.caretVisible ? this.colors().ink : Color.Transparent)
      }
    }.id('narrative-letter-paragraph-' + segment.paragraph + '-' + segment.start)
      .width('100%').constraintSize({ minHeight: LINE }).fontFamily(this.displayFont)
      .fontSize(FONT).lineHeight('32.3fp').fontColor(this.colors().ink)
      .textAlign(this.displayAlign(segment)).wordBreak(WordBreak.BREAK_WORD)
  }

  @Builder
  private verticalParagraph(segment: LetterSegment, current: boolean) {
    Row() {
      ForEach(this.verticalColumns(this.visibleText(segment), current && this.showCursor(segment)),
        (column: LetterColumn, index: number) => {
          Column() {
            if (column.text.length > 0) {
              // The bundled Noto Serif SC exposes the OpenType substitutions for upright vertical punctuation.
              Text(column.text).id('narrative-letter-column-' + segment.paragraph + '-' + segment.start + '-' + index)
                .fontFamily(this.displayFont).fontSize(FONT).lineHeight('19.04fp').fontFeature('"vert" on')
                .width('100%').textAlign(TextAlign.Center).textDirection(TextDirection.LTR).fontColor(this.colors().ink)
                .accessibilityText(column.text.replace(/\n/g, ''))
            } else if (!column.caret) {
              Blank().height(this.fontVp(VERTICAL_LETTER)).accessibilityLevel('no')
            }
            if (column.caret) {
              Column().id('narrative-letter-vertical-caret')
                .width(this.fontVp(VERTICAL_CARET_WIDTH)).height(this.fontVp(VERTICAL_CARET_HEIGHT))
                .backgroundColor(this.colors().ink).opacity(this.caretVisible ? 1 : 0).accessibilityLevel('no')
            }
          }.width(this.fontVp(VERTICAL_COLUMN)).height('100%').justifyContent(
            this.displayAlign(segment) === TextAlign.Center ? FlexAlign.Center :
              this.displayAlign(segment) === TextAlign.End ? FlexAlign.End : FlexAlign.Start)
        }, (column: LetterColumn, index: number) => index + ':' + column.text + ':' + column.caret)
    }.height('100%').direction(Direction.Rtl).justifyContent(FlexAlign.Start)
  }

  @Builder
  private paperBody(current: boolean) {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.classical()) {
        Row({ space: VERTICAL_PARAGRAPH_GAP }) {
          ForEach(this.pages[current ? this.pageIndex : this.previousPage] ?? [], (segment: LetterSegment) => {
            this.verticalParagraph(segment, current)
          }, (segment: LetterSegment) => segment.paragraph + ':' + segment.start + ':' + segment.end)
        }.width('100%').height('100%').direction(Direction.Rtl).justifyContent(FlexAlign.Start)
      } else {
        Column({ space: this.fontVp(PARAGRAPH_GAP) }) {
          ForEach(this.pages[current ? this.pageIndex : this.previousPage] ?? [], (segment: LetterSegment) => {
            this.horizontalParagraph(segment, current)
          }, (segment: LetterSegment) => segment.paragraph + ':' + segment.start + ':' + segment.end)
        }.width('100%').alignItems(HorizontalAlign.Start)
      }
    }.width('100%').layoutWeight(1).clip(true)
      .onAreaChange((_previous: Area, area: Area) => { if (current) { this.bodyChanged(area); } })
  }

  @Builder
  private sheet(current: boolean) {
    Stack() {
      if (this.paperImage().length > 0 && this.assetOwner().length > 0) {
        NarrativeLetterImage({ source: this.paperImage(), ownerKey: this.assetOwner(), imageCache: this.imageCache,
          imageOpacity: 0.18, reducedMotion: this.reducedMotion })
      }
      Column().width('100%').height('100%').padding(12)
        .overlay(this.paperFrame(), { align: Alignment.Center })
        .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      Column() {
        this.paperHeader()
        Column() {
          this.paperBody(current)
        }.width('100%').layoutWeight(1).padding({ top: 30, bottom: 16 })
      }.width('100%').height('100%').padding({ top: 48, bottom: 32, left: 30, right: 30 })
    }.width('100%').height('100%').backgroundColor(this.colors().paper)
      .border({ width: 1, color: this.colors().edge }).clip(true)
  }

  @Builder
  private paperFrame() {
    Column().width('100%').height('100%').border({ width: 1, color: this.colors().frame })
      .hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
  }

  @Builder
  private readerPaper() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor(this.colors().paper)
        .border({ width: 1, color: this.colors().edge }).opacity(0.74)
        .translate({ x: -7, y: 5 }).rotate({ angle: -0.28 }).hitTestBehavior(HitTestMode.None)
      Column().width('100%').height('100%').backgroundColor(this.colors().paper)
        .border({ width: 1, color: this.colors().edge })
        .translate({ x: 9, y: 10 }).rotate({ angle: 0.35 }).hitTestBehavior(HitTestMode.None)
      Stack() {
        this.sheet(true)
      }.id('narrative-letter-paper').width('100%').height('100%')
        .onAreaChange((_previous: Area, area: Area) => {
          this.paperWidth = Number(area.width);
          this.paperHeight = Number(area.height);
        })
        .accessibilityDescription(this.pages.length <= 1 ? '' : this.canTurn() ?
          (this.classical() ? '可左右滑动翻页。' : '可上下滑动翻页。') : '打字完成或显示全文后可以翻页。')
        .gesture(PanGesture({ fingers: 1, direction: this.classical() ? PanDirection.Horizontal : PanDirection.Vertical,
          distance: 12 }).onActionEnd((event: GestureEvent) => this.finishSwipe(event)))
      if (this.previousPage >= 0) {
        Stack() {
          this.sheet(false)
        }.id('narrative-letter-turning').width('100%').height('100%')
          .rotate({ x: this.classical() ? 0 : 1, y: this.classical() ? 1 : 0, perspective: 1200,
            angle: this.turnMotion ? this.turnDirection * (this.classical() ? -28 : 28) : 0 })
          .translate({ x: this.turnMotion && this.classical() ? this.turnDirection * -this.bodyWidth : 0,
            y: this.turnMotion && !this.classical() ? this.turnDirection * -this.bodyHeight : 0 })
          .opacity(this.turnMotion ? 0 : 1).hitTestBehavior(HitTestMode.None)
          .accessibilityLevel('no-hide-descendants').onAppear(() => this.startTurnMotion())
        if (!this.reducedMotion && this.paperWidth > 0 && this.paperHeight > 0) {
          NarrativeLetterCurl({ paper: this.colors().paper, horizontal: this.classical(), turnSign: this.turnDirection,
            sheetWidth: this.paperWidth, sheetHeight: this.paperHeight })
        }
      }
    }.width('100%').layoutWeight(1).transition(this.readerTransition())
  }

  @Builder
  private musicButton() {
    Stack() {
      if (this.musicState === 'playing' && this.foreground && !this.reducedMotion) {
        NarrativeMusicPulse()
      }
      Button(this.musicState === 'playing' ? 'Ⅱ' : '♪', { type: ButtonType.Circle })
        .id('narrative-letter-audio').width(48).height(48).backgroundColor('#E011120F')
        .fontColor('#D9C98F').fontSize(19).border({ width: 1, color: '#665B3E' })
        .accessibilityText(this.musicState === 'playing' || this.musicState === 'loading' ? '暂停' : '播放')
        .onClick(() => this.audio.toggleMusic())
    }.width(48).height(48)
  }

  @Builder
  private controls() {
    Column({ space: 8 }) {
      if (this.pages.length > 1) {
        Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center, wrap: FlexWrap.Wrap,
          space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(4) } }) {
          NarrativeLetterControl({ controlId: 'narrative-letter-previous', label: '上一页',
            available: this.canTurn() && this.pageIndex > 0, strokeTint: this.controlOutline(),
            action: () => this.manualTurn(-1) })
          Text((this.pageIndex + 1) + ' / ' + this.pages.length).id('narrative-letter-page-count')
            .fontSize(12).fontFamily('monospace').fontColor('#AAA79F').textAlign(TextAlign.Center)
            .accessibilityText('第 ' + (this.pageIndex + 1) + ' 页，共 ' + this.pages.length + ' 页')
          NarrativeLetterControl({ controlId: 'narrative-letter-next', label: '下一页',
            available: this.canTurn() && this.pageIndex + 1 < this.pages.length, strokeTint: this.controlOutline(),
            action: () => this.manualTurn(1) })
        }.width('100%')
      }
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center, wrap: FlexWrap.Wrap,
        space: { main: LengthMetrics.vp(6), cross: LengthMetrics.vp(4) } }) {
        if (!this.finished) {
          NarrativeLetterControl({ controlId: 'narrative-letter-show-all', label: '显示全文',
            strokeTint: this.controlOutline(), action: () => this.skipTyping() })
        }
        Row({ space: 8 }) {
          NarrativeLetterControl({ controlId: 'narrative-letter-close', label: '收起信件',
            strokeTint: this.controlOutline(), action: () => this.close() })
          if (!this.finished && this.letter.mainAudioUrl.length > 0) { this.musicButton() }
        }
        if (this.finished && this.letter.mainAudioUrl.length > 0) { this.musicButton() }
      }.width('100%')
    }.id('narrative-letter-controls').width('100%').padding({ left: 10, right: 10, top: 9, bottom: 9 })
      .backgroundColor('#C70E0F0C').border({ width: 1, color: this.controlOutline(true) })
  }

  build() {
    Stack() {
      if (this.letter.pageBackgroundUrl.length > 0 && this.assetOwner().length > 0) {
        NarrativeLetterImage({ source: this.letter.pageBackgroundUrl, ownerKey: this.assetOwner(),
          imageCache: this.imageCache, reducedMotion: this.reducedMotion, atmosphere: true })
      }
      Column().width('100%').height('100%').linearGradient({ direction: GradientDirection.Bottom,
        colors: this.letter.variant === 'magic' ? [['#B3040808', 0], ['#EB040808', 1]] :
          [['#A30A0B09', 0], ['#E00A0B09', 1]] }).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      if (this.letter.variant === 'magic') {
        Column().width('100%').height('100%').radialGradient({ center: ['50%', '40%'], radius: '50%',
          colors: [['#3D2A6C63', 0], [Color.Transparent, 1]] }).hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
      }
      if (this.opened) {
        Column({ space: 12 }) {
          this.readerPaper()
          this.controls()
        }.width('100%').constraintSize({ maxWidth: 808, maxHeight: 926 }).height('100%')
          .padding({ top: this.topInset + 48, bottom: this.bottomInset + 18, left: 14, right: 14 })
      } else {
        Column() {
          this.envelope()
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
          .padding({ top: this.topInset + 48, bottom: this.bottomInset + 18 })
        Column() {
          NarrativeLetterControl({ controlId: 'narrative-letter-return', label: '← 返回冒险',
            isReturn: true, action: () => this.returnToQuest() })
        }.position({ x: 14, y: this.topInset + 12 })
      }
    }.id('narrative-letter').width('100%').height('100%').clip(true).backgroundColor(this.colors().canvas)
      .onAreaChange((_previous: Area, current: Area) => {
        const width: number = Number(current.width);
        if (Number.isFinite(width) && width > 0) { this.sceneWidth = width; }
      })
  }
}
