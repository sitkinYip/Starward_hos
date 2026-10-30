import { image } from '@kit.ImageKit';
import { AvatarImage } from '../business/models';
import { decodeAvatarImage, releaseAvatarPixelMap } from '../platform/AvatarEditor';

/** No URL or credentials reach this view; failed decoding returns the traveller initial. */
@ComponentV2
export struct StarwardPlayerAvatar {
  @Param name: string = '';
  @Param avatar: AvatarImage | null = null;
  @Param avatarSize: number = 44;
  @Event decodeFailed: (avatar: AvatarImage) => void = () => {};
  @Local private pixels: image.PixelMap | undefined = undefined;
  private generation: number = 0;
  private active: boolean = false;

  aboutToAppear(): void {
    this.active = true;
    this.load();
  }

  @Monitor('avatar')
  avatarChanged(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const generation: number = ++this.generation;
    const previous: image.PixelMap | undefined = this.pixels;
    this.pixels = undefined;
    await releaseAvatarPixelMap(previous);
    if (!this.active || generation !== this.generation || this.avatar === null || this.avatar.data.byteLength === 0) {
      return;
    }
    const requested: AvatarImage = this.avatar;
    try {
      const pixels: image.PixelMap = await decodeAvatarImage(requested.data);
      if (!this.active || generation !== this.generation) {
        await releaseAvatarPixelMap(pixels);
        return;
      }
      this.pixels = pixels;
    } catch {
      if (this.active && generation === this.generation && this.avatar === requested) {
        this.pixels = undefined;
        this.decodeFailed(requested);
      }
    }
  }

  aboutToDisappear(): void {
    this.active = false;
    this.generation++;
    const previous: image.PixelMap | undefined = this.pixels;
    this.pixels = undefined;
    releaseAvatarPixelMap(previous);
  }

  private initial(): string {
    const value: string = this.name.trim();
    return value.length > 0 ? Array.from(value)[0] : '旅';
  }

  build() {
    Stack() {
      if (this.pixels !== undefined) {
        Image(this.pixels).width(this.avatarSize).height(this.avatarSize).objectFit(ImageFit.Cover)
          .draggable(false).accessibilityLevel('no')
      } else {
        Text(this.initial()).fontSize(this.avatarSize * 0.44).fontColor($r('app.color.accent_text'))
          .maxLines(1).accessibilityLevel('no')
      }
    }.width(this.avatarSize).height(this.avatarSize).borderRadius(this.avatarSize / 2).clip(true)
      .backgroundColor($r('app.color.surface')).border({ width: 1, color: $r('app.color.border') })
      .accessibilityText(`${this.name || '冒险者'}的头像`).accessibilityLevel('no')
  }
}
