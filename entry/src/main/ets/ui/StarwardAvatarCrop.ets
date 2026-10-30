import { image } from '@kit.ImageKit';
import { AvatarUpload, GameFailure } from '../business/models';
import { AvatarSelection, AvatarPreview, releaseAvatarPixelMap } from '../platform/AvatarEditor';

/** Content for an official bindSheet. Native gestures and sliders describe the same square crop. */
@ComponentV2
export struct StarwardAvatarCrop {
  @Param selection: AvatarSelection | null = null;
  @Event confirmed: (upload: AvatarUpload) => void = () => {};
  @Event cancelled: () => void = () => {};
  @Event reselect: () => void = () => {};
  @Local private pixels: image.PixelMap | undefined = undefined;
  @Local private imageWidth: number = 1;
  @Local private imageHeight: number = 1;
  @Local private cropSide: number = 280;
  @Local private zoom: number = 1;
  @Local private horizontal: number = 50;
  @Local private vertical: number = 50;
  @Local private loading: boolean = true;
  @Local private processing: boolean = false;
  @Local private error: string = '';
  private generation: number = 0;
  private active: boolean = false;
  private pinchZoom: number = 1;
  private panHorizontal: number = 50;
  private panVertical: number = 50;

  aboutToAppear(): void {
    this.active = true;
    this.load();
  }

  @Monitor('selection')
  selectionChanged(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const generation: number = ++this.generation;
    const selection: AvatarSelection | null = this.selection;
    const previous: image.PixelMap | undefined = this.pixels;
    this.pixels = undefined;
    await releaseAvatarPixelMap(previous);
    if (!this.active || generation !== this.generation) {
      return;
    }
    this.loading = true;
    this.error = '';
    this.zoom = 1;
    this.horizontal = 50;
    this.vertical = 50;
    if (!this.active || selection === null || !selection.isActive()) {
      this.loading = false;
      return;
    }
    let source: image.ImageSource | undefined = undefined;
    let pixels: image.PixelMap | undefined = undefined;
    try {
      const preview: AvatarPreview = await selection.prepare();
      if (!this.active || generation !== this.generation || !selection.isActive()) {
        return;
      }
      source = image.createImageSource(preview.data);
      pixels = await source.createPixelMap();
      if (!this.active || generation !== this.generation || !selection.isActive()) {
        await releaseAvatarPixelMap(pixels);
        pixels = undefined;
        return;
      }
      this.imageWidth = preview.width;
      this.imageHeight = preview.height;
      this.pixels = pixels;
      pixels = undefined;
    } catch (error) {
      if (this.active && generation === this.generation) {
        this.error = error instanceof GameFailure ? error.message : '图片处理失败，请重新选择 JPG、PNG 或 WebP 图片。';
      }
    } finally {
      await releaseAvatarPixelMap(pixels);
      if (source !== undefined) {
        await source.release();
      }
      if (generation === this.generation) {
        this.loading = false;
      }
    }
  }

  aboutToDisappear(): void {
    this.active = false;
    this.generation++;
    const previous: image.PixelMap | undefined = this.pixels;
    this.pixels = undefined;
    releaseAvatarPixelMap(previous);
    this.selection?.dispose();
  }

  private clamp(value: number, minimum: number, maximum: number): number {
    return Math.max(minimum, Math.min(maximum, value));
  }

  private displayWidth(): number {
    return this.imageWidth * this.cropSide / Math.min(this.imageWidth, this.imageHeight) * this.zoom;
  }

  private displayHeight(): number {
    return this.imageHeight * this.cropSide / Math.min(this.imageWidth, this.imageHeight) * this.zoom;
  }

  private move(event: GestureEvent): void {
    const overflowX: number = this.displayWidth() - this.cropSide;
    const overflowY: number = this.displayHeight() - this.cropSide;
    this.horizontal = overflowX > 0 ? this.clamp(this.panHorizontal - event.offsetX * 100 / overflowX, 0, 100) : 50;
    this.vertical = overflowY > 0 ? this.clamp(this.panVertical - event.offsetY * 100 / overflowY, 0, 100) : 50;
  }

  private async confirm(): Promise<void> {
    if (this.processing || this.loading || this.pixels === undefined || this.selection === null) {
      return;
    }
    const generation: number = this.generation;
    const selection: AvatarSelection = this.selection;
    this.processing = true;
    this.error = '';
    try {
      const upload: AvatarUpload = await selection.crop(this.zoom, this.horizontal, this.vertical);
      if (this.active && generation === this.generation && selection.isActive()) {
        this.confirmed(upload);
      }
    } catch (error) {
      if (this.active && generation === this.generation) {
        this.error = error instanceof GameFailure ? error.message : '图片处理失败，请重新选择 JPG、PNG 或 WebP 图片。';
      }
    } finally {
      if (generation === this.generation) {
        this.processing = false;
      }
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('拖动照片或双指缩放，选择正方形范围。确认后保存资料即可上传。')
          .fontSize(13).fontColor($r('app.color.muted'))
        if (this.loading) {
          LoadingProgress().width(40).height(40)
          Text('正在准备照片…').id('avatar-crop-loading').fontColor($r('app.color.muted'))
        } else if (this.pixels !== undefined) {
          Stack({ alignContent: Alignment.TopStart }) {
            Image(this.pixels).width(this.displayWidth()).height(this.displayHeight()).objectFit(ImageFit.Fill)
              .position({ x: -(this.displayWidth() - this.cropSide) * this.horizontal / 100,
                y: -(this.displayHeight() - this.cropSide) * this.vertical / 100 })
              .draggable(false).accessibilityLevel('no')
          }.id('avatar-crop-preview').width('100%').aspectRatio(1).clip(true)
            .backgroundColor(Color.White).border({ width: 1, color: $r('app.color.border') })
            .onAreaChange((_previous: Area, current: Area) => {
              const side: number = Number(current.width);
              if (Number.isFinite(side) && side > 0) {
                this.cropSide = side;
              }
            })
            .enabled(!this.processing)
            .gesture(GestureGroup(GestureMode.Parallel,
              PinchGesture({ fingers: 2 })
                .onActionStart(() => { this.pinchZoom = this.zoom; })
                .onActionUpdate((event: GestureEvent) => { this.zoom = this.clamp(this.pinchZoom * event.scale, 1, 4); }),
              PanGesture({ fingers: 1, direction: PanDirection.All })
                .onActionStart(() => { this.panHorizontal = this.horizontal; this.panVertical = this.vertical; })
                .onActionUpdate((event: GestureEvent) => this.move(event))
            ))
          Text('缩放').fontSize(13).fontColor($r('app.color.muted'))
          Slider({ value: this.zoom, min: 1, max: 4, step: 0.01 }).id('avatar-crop-zoom')
            .selectedColor($r('app.color.accent'))
            .enabled(!this.processing).accessibilityText('缩放')
            .onChange((value: number) => { this.zoom = value; })
          Text('水平位置').fontSize(13).fontColor($r('app.color.muted'))
          Slider({ value: this.horizontal, min: 0, max: 100, step: 1 }).id('avatar-crop-horizontal')
            .selectedColor($r('app.color.accent'))
            .enabled(!this.processing).accessibilityText('水平位置')
            .onChange((value: number) => { this.horizontal = value; })
          Text('垂直位置').fontSize(13).fontColor($r('app.color.muted'))
          Slider({ value: this.vertical, min: 0, max: 100, step: 1 }).id('avatar-crop-vertical')
            .selectedColor($r('app.color.accent'))
            .enabled(!this.processing).accessibilityText('垂直位置')
            .onChange((value: number) => { this.vertical = value; })
        }
        if (this.error.length > 0) {
          Text(this.error).id('avatar-crop-error').fontColor($r('app.color.danger')).fontSize(13)
        }
        Button(this.processing ? '正在压缩…' : '使用此头像').id('avatar-crop-confirm').width('100%').height(52)
          .fontColor($r('app.color.on_accent')).backgroundColor($r('app.color.accent'))
          .enabled(!this.loading && !this.processing && this.pixels !== undefined).onClick(() => this.confirm())
        Button('重新选择照片').id('avatar-crop-reselect').width('100%').height(44)
          .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
          .enabled(!this.processing).onClick(() => this.reselect())
        Button('取消').id('avatar-crop-cancel').width('100%').height(44)
          .fontColor($r('app.color.accent_text')).backgroundColor($r('app.color.accent_faint'))
          .enabled(!this.processing).onClick(() => this.cancelled())
      }.width('100%').padding(24).alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').scrollBar(BarState.Off)
  }
}
