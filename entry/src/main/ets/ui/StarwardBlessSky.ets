import { displaySync } from '@kit.ArkGraphics2D';
import { LengthMetricsUnit } from '@kit.ArkUI';

const PARTICLE_COLORS: string[] = ['#e0b0ff', '#ffb7c5', '#b4e4ff', '#ffffff', '#e6e6fa'];
const STAR_COLORS: string[] = ['#ffffff', '#f0f8ff', '#e0ffff', '#fffacd', '#f0e68c'];
const BRIGHTNESS: number[] = [0.44, 0.68, 0.92];
const CIRCLE: number = Math.PI * 2;
const FRAME_MS: number = 1000 / 30;
const MOBILE_WIDTH: number = 768;

class BlessPoint {
  readonly x: number;
  readonly y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

class BlessGlyphs {
  readonly lines: string[];
  readonly fontSize: number;
  readonly lineHeight: number;

  constructor(lines: string[], fontSize: number) {
    this.lines = lines;
    this.fontSize = fontSize;
    this.lineHeight = fontSize * 1.5;
  }

  baseline(height: number, index: number): number {
    return (height - (this.lines.length - 1) * this.lineHeight) / 2 + index * this.lineHeight;
  }
}

class BlessParticle {
  x: number;
  y: number;
  target: BlessPoint | null = null;
  vx: number = (Math.random() - 0.5) * 1.5;
  vy: number = (Math.random() - 0.5) * 1.5;
  readonly radius: number = Math.random() * 1.2 + 0.3;
  readonly flicker: number = Math.random() * 0.005 + 0.002;
  readonly phase: number = Math.random() * CIRCLE;
  readonly ease: number = Math.random() * 0.04 + 0.03;
  alpha: number = Math.random() * 0.6 + 0.4;

  constructor(width: number, height: number) {
    this.x = Math.random() * width;
    this.y = Math.random() * height;
  }

  release(spread: number): void {
    this.target = null;
    this.vx = (Math.random() - 0.5) * spread;
    this.vy = (Math.random() - 0.5) * spread;
  }

  step(width: number, height: number, time: number, frames: number, touch: BlessPoint | null): void {
    const target: BlessPoint | null = this.target;
    if (target !== null) {
      const amount: number = 1 - Math.pow(1 - this.ease, frames);
      this.x += (target.x - this.x) * amount;
      this.y += (target.y - this.y) * amount;
      this.alpha = 0.75 + Math.sin(time * this.flicker + this.phase) * 0.25;
    } else {
      this.x += this.vx * frames;
      this.y += this.vy * frames;
      if (this.x < 0 || this.x > width) {
        this.vx *= -1;
        this.x = Math.max(0, Math.min(this.x, width));
      }
      if (this.y < 0 || this.y > height) {
        this.vy *= -1;
        this.y = Math.max(0, Math.min(this.y, height));
      }
      this.alpha = Math.max(0.4, this.alpha - frames * 0.005);
    }
    if (touch === null) { return; }
    const dx: number = touch.x - this.x;
    const dy: number = touch.y - this.y;
    const distanceSquared: number = dx * dx + dy * dy;
    if (distanceSquared > 0 && distanceSquared < 6400) {
      const distance: number = Math.sqrt(distanceSquared);
      const repulsion: number = (80 - distance) * 0.17 / distance;
      this.x -= dx * repulsion;
      this.y -= dy * repulsion;
    }
  }
}

class BlessStar {
  readonly x: number;
  readonly y: number;
  readonly radius: number = Math.random() * 1.5 + 0.3;
  readonly color: string = STAR_COLORS[Math.floor(Math.random() * STAR_COLORS.length)];
  readonly alpha: number = Math.random() * 0.6 + 0.1;
  readonly speed: number = Math.random() * 0.003 + 0.0005;
  readonly phase: number = Math.random() * CIRCLE;

  constructor(width: number, height: number) {
    this.x = Math.random() * width;
    this.y = Math.random() * height;
  }

  brightness(time: number): number {
    const primary: number = Math.sin(time * this.speed + this.phase);
    const secondary: number = Math.sin(time * this.speed * 2.5 + this.phase);
    return this.alpha * (1 + (primary + secondary * 0.5) * 0.2);
  }
}

class BlessMeteor {
  x: number;
  y: number;
  readonly length: number = Math.random() * 120 + 60;
  readonly speed: number = Math.random() * 15 + 10;
  readonly radius: number = Math.random() * 1.5 + 0.5;
  readonly angle: number = Math.PI / 4 + (Math.random() - 0.5) * 0.1;

  constructor(width: number, height: number) {
    this.x = Math.random() * width * 1.2 - width * 0.1;
    this.y = Math.random() * height * 0.6;
  }
}

function createGlyphs(context: CanvasRenderingContext2D, phrase: string, width: number, height: number): BlessGlyphs {
  const size: number = Math.max(14, width < MOBILE_WIDTH ? Math.floor(width / (phrase.length > 10 ? 10 : 8)) : 75);
  const font: string = `bold ${size}vp sans-serif`;
  const capacity: number = Math.max(1, Math.floor(height * 0.86 / (size * 1.5)));
  const maxWidth: number = width * 0.9;
  const lines: string[] = [];
  context.font = font;
  const paragraphs: string[] = phrase.replace(/\\n/g, '\n').split('\n');
  for (const paragraph of paragraphs) {
    let line: string = '';
    for (const character of paragraph) {
      const candidate: string = line + character;
      if (line.length > 0 && context.measureText(candidate).width > maxWidth) {
        lines.push(line);
        line = character;
        if (lines.length === capacity) { break; }
      } else {
        line = candidate;
      }
    }
    lines.push(line);
    if (lines.length > capacity) { break; }
  }
  if (lines.length > capacity) {
    lines.length = capacity;
    lines[capacity - 1] += '…';
  }
  return new BlessGlyphs(lines, size);
}

function sampleGlyphs(glyphs: BlessGlyphs, width: number, height: number): BlessPoint[] {
  // The alpha mask is sampled only when the phrase or viewport changes. Use logical-sized pixels
  // for stable density on high-DPI phones and cap native raster memory for larger windows.
  const scale: number = Math.min(1, 1024 / Math.max(width, height));
  const rasterWidth: number = Math.max(1, Math.floor(width * scale));
  const rasterHeight: number = Math.max(1, Math.floor(height * scale));
  const mask: OffscreenCanvasRenderingContext2D = new OffscreenCanvasRenderingContext2D(rasterWidth,
    rasterHeight, new RenderingContextSettings(true), LengthMetricsUnit.PX);
  mask.font = `bold ${glyphs.fontSize * scale}px sans-serif`;
  mask.textAlign = 'center';
  mask.textBaseline = 'middle';
  mask.fillStyle = '#ffffff';
  mask.strokeStyle = '#ffffff';
  mask.lineWidth = scale;
  for (let index = 0; index < glyphs.lines.length; index++) {
    const y: number = glyphs.baseline(height, index) * scale;
    mask.fillText(glyphs.lines[index], rasterWidth / 2, y, rasterWidth * 0.9);
    mask.strokeText(glyphs.lines[index], rasterWidth / 2, y, rasterWidth * 0.9);
  }
  const pixels: ImageData = mask.getImageData(0, 0, rasterWidth, rasterHeight);
  const points: BlessPoint[] = [];
  const step: number = width < MOBILE_WIDTH ? 2 : 3;
  const threshold: number = width < MOBILE_WIDTH ? 150 : 110;
  for (let y = 0; y < pixels.height; y += step) {
    for (let x = 0; x < pixels.width; x += step) {
      if (pixels.data[(y * pixels.width + x) * 4 + 3] > threshold) {
        points.push(new BlessPoint(x / scale, y / scale));
      }
    }
  }
  for (let index = points.length - 1; index > 0; index--) {
    const alternate: number = Math.floor(Math.random() * (index + 1));
    const point: BlessPoint = points[index];
    points[index] = points[alternate];
    points[alternate] = point;
  }
  return points;
}

@ComponentV2
export struct StarwardBlessSky {
  @Param phrase: string = '';
  @Param foreground: boolean = true;
  @Param reducedMotion: boolean = true;
  private readonly canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private sync: displaySync.DisplaySync | null = null;
  private ready: boolean = false;
  private stageWidth: number = 0;
  private stageHeight: number = 0;
  private lastFrame: number = 0;
  private elapsed: number = 0;
  private particleBatches: BlessParticle[][] = [];
  private stars: BlessStar[] = [];
  private meteors: BlessMeteor[] = [];
  private glyphs: BlessGlyphs | null = null;
  private glyphsSampled: boolean = false;
  private preparedPhrase: string | null = null;
  private preparedReducedMotion: boolean = true;
  private touch: BlessPoint | null = null;
  private touchExpires: number = 0;

  aboutToDisappear(): void {
    this.ready = false;
    this.stopFrames();
    this.particleBatches = [];
    this.stars = [];
    this.meteors = [];
    this.glyphs = null;
    this.touch = null;
  }

  @Monitor('foreground', 'reducedMotion')
  refreshStage(): void {
    if (!this.ready || !this.foreground || this.stageWidth <= 0 || this.stageHeight <= 0) {
      this.touch = null;
      this.stopFrames();
      return;
    }
    if (this.reducedMotion) {
      this.touch = null;
      this.meteors = [];
      this.stopFrames();
    }
    if (this.particleBatches.length === 0) { this.seed(); }
    this.updateGlyphs();
    if (!this.reducedMotion && this.sync === null) { this.startFrames(); }
    this.draw(this.reducedMotion || this.sync === null);
  }

  @Monitor('phrase')
  phraseChanged(): void {
    if (this.ready && this.foreground && this.stageWidth > 0 && this.stageHeight > 0) {
      this.updateGlyphs();
      this.draw(this.reducedMotion || this.sync === null);
    }
  }

  private canvasReady(): void {
    this.ready = true;
    if (this.stageWidth <= 0 || this.stageHeight <= 0) {
      this.stageWidth = this.canvas.width;
      this.stageHeight = this.canvas.height;
    }
    this.refreshStage();
  }

  private resize(width: number, height: number): void {
    if (!Number.isFinite(width) || !Number.isFinite(height) ||
      width <= 0 || height <= 0 || (width === this.stageWidth && height === this.stageHeight)) { return; }
    this.stageWidth = width;
    this.stageHeight = height;
    this.particleBatches = [];
    this.refreshStage();
  }

  private seed(): void {
    const count: number = (this.stageWidth < MOBILE_WIDTH ? 1800 : 2200) / PARTICLE_COLORS.length;
    this.particleBatches = PARTICLE_COLORS.map((): BlessParticle[] => {
      const batch: BlessParticle[] = [];
      for (let index = 0; index < count; index++) { batch.push(new BlessParticle(this.stageWidth, this.stageHeight)); }
      return batch;
    });
    this.stars = [];
    for (let index = 0; index < 300; index++) { this.stars.push(new BlessStar(this.stageWidth, this.stageHeight)); }
    this.meteors = [];
    this.preparedPhrase = null;
  }

  private updateGlyphs(): void {
    if (this.preparedPhrase === this.phrase && this.preparedReducedMotion === this.reducedMotion) { return; }
    this.preparedPhrase = this.phrase;
    this.preparedReducedMotion = this.reducedMotion;
    if (this.phrase.length === 0 && this.glyphs === null) { return; }
    this.glyphs = this.phrase.length > 0 ? createGlyphs(this.canvas, this.phrase, this.stageWidth, this.stageHeight) : null;
    let points: BlessPoint[] = [];
    const glyphs: BlessGlyphs | null = this.glyphs;
    if (glyphs !== null && !this.reducedMotion) {
      try { points = sampleGlyphs(glyphs, this.stageWidth, this.stageHeight); } catch { /* Readable text remains available. */ }
    }
    this.glyphsSampled = points.length > 0;
    for (let color = 0; color < this.particleBatches.length; color++) {
      const batch: BlessParticle[] = this.particleBatches[color];
      for (let index = 0; index < batch.length; index++) {
        const target: number = index * this.particleBatches.length + color;
        if (target < points.length) {
          batch[index].target = points[target];
        } else {
          batch[index].release(glyphs === null ? 3 : 0.5);
        }
      }
    }
  }

  private startFrames(): void {
    try {
      this.sync = displaySync.create();
      this.sync.setExpectedFrameRateRange({ min: 15, max: 60, expected: 30 });
      this.sync.on('frame', (frame: displaySync.IntervalInfo) => this.tick(frame.timestamp / 1e6));
      this.sync.start();
    } catch {
      this.stopFrames();
    }
  }

  private stopFrames(): void {
    const sync: displaySync.DisplaySync | null = this.sync;
    this.sync = null;
    this.lastFrame = 0;
    if (sync === null) { return; }
    sync.stop();
    sync.off('frame');
  }

  private tick(timestamp: number): void {
    if (!this.foreground || this.reducedMotion || !this.ready || this.sync === null) { return; }
    const delta: number = this.lastFrame === 0 ? FRAME_MS : timestamp - this.lastFrame;
    if (delta < FRAME_MS - 1) { return; }
    this.lastFrame = timestamp;
    const step: number = Math.min(delta, 50);
    this.elapsed += step;
    const frames: number = step / (1000 / 60);
    const pointer: BlessPoint | null = this.elapsed < this.touchExpires ? this.touch : null;
    for (const batch of this.particleBatches) {
      for (const particle of batch) { particle.step(this.stageWidth, this.stageHeight, this.elapsed, frames, pointer); }
    }
    if (this.meteors.length < 3 && Math.random() < 0.02 * frames) {
      this.meteors.push(new BlessMeteor(this.stageWidth, this.stageHeight));
    }
    for (let index = this.meteors.length - 1; index >= 0; index--) {
      const meteor: BlessMeteor = this.meteors[index];
      meteor.x -= meteor.speed * Math.cos(meteor.angle) * frames;
      meteor.y += meteor.speed * Math.sin(meteor.angle) * frames;
      if (meteor.x < -meteor.length || meteor.y > this.stageHeight + meteor.length) { this.meteors.splice(index, 1); }
    }
    this.draw(false);
  }

  private circle(x: number, y: number, radius: number): void {
    this.canvas.moveTo(x + radius, y);
    this.canvas.arc(x, y, radius, 0, CIRCLE);
  }

  private paintStars(still: boolean): void {
    const count: number = still ? Math.min(this.stars.length, 120) : this.stars.length;
    for (let index = 0; index < count; index++) {
      const star: BlessStar = this.stars[index];
      this.canvas.globalAlpha = still ? star.alpha : star.brightness(this.elapsed);
      this.canvas.fillStyle = star.color;
      this.canvas.beginPath();
      this.canvas.arc(star.x, star.y, star.radius, 0, CIRCLE);
      this.canvas.fill();
    }
  }

  private paintMeteors(): void {
    for (const meteor of this.meteors) {
      const tailX: number = meteor.x + meteor.length * Math.cos(meteor.angle);
      const tailY: number = meteor.y - meteor.length * Math.sin(meteor.angle);
      const trail: CanvasGradient = this.canvas.createLinearGradient(meteor.x, meteor.y, tailX, tailY);
      trail.addColorStop(0, 'rgba(255,255,255,0.9)');
      trail.addColorStop(0.3, 'rgba(180,200,255,0.2)');
      trail.addColorStop(1, 'rgba(255,255,255,0)');
      this.canvas.globalAlpha = 1;
      this.canvas.strokeStyle = trail;
      this.canvas.lineWidth = meteor.radius;
      this.canvas.lineCap = 'round';
      this.canvas.beginPath();
      this.canvas.moveTo(meteor.x, meteor.y);
      this.canvas.lineTo(tailX, tailY);
      this.canvas.stroke();
    }
  }

  private paintGlyphs(solid: boolean): void {
    const glyphs: BlessGlyphs | null = this.glyphs;
    if (glyphs === null) { return; }
    this.canvas.save();
    this.canvas.globalAlpha = 1;
    this.canvas.font = `bold ${glyphs.fontSize}vp sans-serif`;
    this.canvas.textAlign = 'center';
    this.canvas.textBaseline = 'middle';
    this.canvas.lineWidth = 1;
    this.canvas.shadowColor = 'rgba(135,206,250,0.4)';
    this.canvas.shadowBlur = 22;
    this.canvas.fillStyle = '#ecebff';
    this.canvas.strokeStyle = 'rgba(135,206,250,0.10)';
    const x: number = this.stageWidth / 2;
    for (let index = 0; index < glyphs.lines.length; index++) {
      const y: number = glyphs.baseline(this.stageHeight, index);
      if (solid) {
        this.canvas.fillText(glyphs.lines[index], x, y, this.stageWidth * 0.9);
      } else {
        this.canvas.strokeText(glyphs.lines[index], x, y, this.stageWidth * 0.9);
      }
    }
    this.canvas.restore();
  }

  private paintParticles(still: boolean): void {
    for (let index = 0; index < this.particleBatches.length; index++) {
      const batch: BlessParticle[] = this.particleBatches[index];
      this.canvas.fillStyle = PARTICLE_COLORS[index];
      this.canvas.globalAlpha = still ? 0.24 : 0.20;
      this.canvas.beginPath();
      const count: number = still ? Math.min(90, batch.length) : batch.length;
      for (let i = 0; i < count; i++) {
        const particle: BlessParticle = batch[i];
        if (still || particle.target !== null || (particle.radius > 1 && particle.alpha > 0.5)) {
          this.circle(particle.x, particle.y, particle.radius * (still ? 0.8 : 2.6));
        }
      }
      this.canvas.fill();
      if (still) { continue; }
      for (let band = 0; band < BRIGHTNESS.length; band++) {
        this.canvas.globalAlpha = BRIGHTNESS[band];
        this.canvas.beginPath();
        for (const particle of batch) {
          const intensity: number = particle.alpha < 0.55 ? 0 : particle.alpha < 0.8 ? 1 : 2;
          if (intensity === band) { this.circle(particle.x, particle.y, particle.radius); }
        }
        this.canvas.fill();
      }
    }
  }

  private draw(still: boolean): void {
    this.canvas.clearRect(0, 0, this.stageWidth, this.stageHeight);
    this.paintStars(still);
    if (!still) { this.paintMeteors(); }
    this.paintParticles(still);
    this.paintGlyphs(still || !this.glyphsSampled);
    this.canvas.globalAlpha = 1;
  }

  private trackTouch(event: TouchEvent): void {
    if (!this.foreground || this.reducedMotion || event.touches.length === 0 ||
      (event.type !== TouchType.Down && event.type !== TouchType.Move)) { return; }
    this.touch = new BlessPoint(event.touches[0].x, event.touches[0].y);
    this.touchExpires = this.elapsed + 2000;
  }

  build() {
    Canvas(this.canvas).id('narrative-bless-sky').width('100%').height('100%')
      .hitTestBehavior(HitTestMode.Transparent).accessibilityLevel('no')
      .onReady(() => this.canvasReady())
      .onAreaChange((_previous: Area, current: Area) => this.resize(Number(current.width), Number(current.height)))
      .onTouch((event: TouchEvent) => this.trackTouch(event))
  }
}
