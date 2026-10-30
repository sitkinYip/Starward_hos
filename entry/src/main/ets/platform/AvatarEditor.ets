import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { AvatarUpload, GameFailure } from '../business/models';

const MAX_ORIGINAL_BYTES: number = 50 * 1024 * 1024;
const MAX_AVATAR_BYTES: number = 200 * 1024;
const PREVIEW_EDGE: number = 2048;
const AVATAR_EDGE: number = 512;

export class AvatarPreview {
  data: ArrayBuffer = new ArrayBuffer(0);
  width: number = 0;
  height: number = 0;
}

function processingFailure(): GameFailure {
  return new GameFailure('AVATAR_PROCESSING_FAILED', '图片处理失败，请重新选择 JPG、PNG 或 WebP 图片。');
}

export async function releaseAvatarPixelMap(value: image.PixelMap | undefined): Promise<void> {
  if (value === undefined) {
    return;
  }
  try {
    await value.release();
  } catch {
    // Cleanup is idempotent; never expose media paths through native error messages.
    return;
  }
}

async function releaseSource(value: image.ImageSource | undefined): Promise<void> {
  if (value === undefined) {
    return;
  }
  try {
    await value.release();
  } catch {
    return;
  }
}

/** @throws {Error} Encoding failures are mapped to path-free errors by the selection owner. */
async function encodeJpeg(value: image.PixelMap, quality: number): Promise<ArrayBuffer> {
  const packer: image.ImagePacker = image.createImagePacker();
  try {
    // Encoding a PixelMap without properties deliberately drops source EXIF metadata.
    return await packer.packToData(value, { format: 'image/jpeg', quality: quality, needsPackProperties: false });
  } finally {
    await packer.release();
  }
}

async function orient(source: image.ImageSource, pixels: image.PixelMap): Promise<void> {
  let orientation: string = '';
  try {
    orientation = await source.getImageProperty(image.PropertyKey.ORIENTATION);
  } catch {
    // Files without EXIF orientation are valid inputs.
    orientation = '';
  }
  if (orientation === 'Top-right' || orientation === '2') {
    await pixels.flip(true, false);
  } else if (orientation === 'Bottom-right' || orientation === '3') {
    await pixels.rotate(180);
  } else if (orientation === 'Bottom-left' || orientation === '4') {
    await pixels.flip(false, true);
  } else if (orientation === 'Left-top' || orientation === '5') {
    await pixels.flip(true, false);
    await pixels.rotate(270);
  } else if (orientation === 'Right-top' || orientation === '6') {
    await pixels.rotate(90);
  } else if (orientation === 'Right-bottom' || orientation === '7') {
    await pixels.flip(true, false);
    await pixels.rotate(90);
  } else if (orientation === 'Left-bottom' || orientation === '8') {
    await pixels.rotate(270);
  }
}

/** @throws {Error} Native pixel failures are handled by the selection owner. */
async function whiteBackground(value: image.PixelMap): Promise<image.PixelMap> {
  const info: image.ImageInfo = await value.getImageInfo();
  const width: number = info.size.width;
  const height: number = info.size.height;
  const stride: number = value.getBytesNumberPerRow();
  const input: ArrayBuffer = new ArrayBuffer(value.getPixelBytesNumber());
  await value.readAllPixelsToBuffer(input);
  const source: Uint8Array = new Uint8Array(input);
  const output: ArrayBuffer = new ArrayBuffer(width * height * 4);
  const destination: Uint8Array = new Uint8Array(output);
  for (let y: number = 0; y < height; y++) {
    for (let x: number = 0; x < width; x++) {
      const from: number = y * stride + x * 4;
      const to: number = (y * width + x) * 4;
      const alpha: number = info.alphaType === image.AlphaType.OPAQUE ? 255 : source[from + 3];
      for (let channel: number = 0; channel < 3; channel++) {
        const component: number = source[from + channel];
        destination[to + channel] = Math.min(255, Math.round(info.alphaType === image.AlphaType.UNPREMUL ?
          component * alpha / 255 + 255 - alpha : component + 255 - alpha));
      }
      destination[to + 3] = 255;
    }
  }
  return image.createPixelMap(output, { size: { width: width, height: height },
    srcPixelFormat: image.PixelMapFormat.RGBA_8888, pixelFormat: image.PixelMapFormat.RGBA_8888,
    alphaType: image.AlphaType.OPAQUE, editable: false });
}

/** One selection owns only a private URI and a bounded in-memory preview. No files are written. */
export class AvatarSelection {
  private uri: string;
  private generation: number = 0;
  private disposed: boolean = false;
  private prepared: AvatarPreview | null = null;
  private preparing: Promise<AvatarPreview> | null = null;

  constructor(uri: string) {
    this.uri = uri;
  }

  isActive(): boolean {
    return !this.disposed;
  }

  private current(generation: number): void {
    if (this.disposed || generation !== this.generation) {
      throw new GameFailure('STALE_AVATAR_SELECTION', '已取消本次头像选择。');
    }
  }

  private async load(generation: number): Promise<AvatarPreview> {
    let file: fileIo.File | undefined = undefined;
    let source: image.ImageSource | undefined = undefined;
    let pixels: image.PixelMap | undefined = undefined;
    let flattened: image.PixelMap | undefined = undefined;
    try {
      this.current(generation);
      file = await fileIo.open(this.uri, fileIo.OpenMode.READ_ONLY);
      const stat: fileIo.Stat = await fileIo.stat(file.fd);
      this.current(generation);
      if (stat.size <= 0 || stat.size > MAX_ORIGINAL_BYTES) {
        throw new GameFailure('AVATAR_TOO_LARGE', '原图超过 50 MB，请选择小一点的图片。');
      }
      source = image.createImageSource(file.fd);
      const info: image.ImageInfo = await source.getImageInfo();
      if (!['image/jpeg', 'image/png', 'image/webp'].includes(info.mimeType)) {
        throw new GameFailure('AVATAR_INVALID_TYPE', '请选择 JPG、PNG 或 WebP 图片。');
      }
      if (!Number.isFinite(info.size.width) || !Number.isFinite(info.size.height) ||
        info.size.width <= 0 || info.size.height <= 0) {
        throw processingFailure();
      }
      const scale: number = Math.min(1, PREVIEW_EDGE / Math.max(info.size.width, info.size.height));
      pixels = await source.createPixelMap({ desiredSize: {
        width: Math.max(1, Math.round(info.size.width * scale)),
        height: Math.max(1, Math.round(info.size.height * scale))
      }, desiredPixelFormat: image.PixelMapFormat.RGBA_8888, editable: true });
      this.current(generation);
      await orient(source, pixels);
      flattened = await whiteBackground(pixels);
      const normalized: image.ImageInfo = await flattened.getImageInfo();
      const preview: AvatarPreview = new AvatarPreview();
      preview.data = await encodeJpeg(flattened, 95);
      preview.width = normalized.size.width;
      preview.height = normalized.size.height;
      this.current(generation);
      this.prepared = preview;
      return preview;
    } catch (error) {
      if (error instanceof GameFailure) {
        throw error;
      }
      throw processingFailure();
    } finally {
      await releaseAvatarPixelMap(flattened);
      await releaseAvatarPixelMap(pixels);
      await releaseSource(source);
      if (file !== undefined) {
        try {
          await fileIo.close(file);
        } catch {
          // The selection has no persistent file or URI outside this owner.
        }
      }
    }
  }

  async prepare(): Promise<AvatarPreview> {
    this.current(this.generation);
    if (this.prepared !== null) {
      return this.prepared;
    }
    if (this.preparing !== null) {
      return this.preparing;
    }
    const task: Promise<AvatarPreview> = this.load(this.generation);
    this.preparing = task;
    try {
      return await task;
    } finally {
      if (this.preparing === task) {
        this.preparing = null;
      }
    }
  }

  async crop(zoom: number, xPercent: number, yPercent: number): Promise<AvatarUpload> {
    const generation: number = this.generation;
    this.current(generation);
    if (![zoom, xPercent, yPercent].every((value: number): boolean => Number.isFinite(value)) ||
      zoom < 1 || zoom > 4 || xPercent < 0 || xPercent > 100 || yPercent < 0 || yPercent > 100) {
      throw processingFailure();
    }
    const preview: AvatarPreview = await this.prepare();
    let source: image.ImageSource | undefined = undefined;
    let pixels: image.PixelMap | undefined = undefined;
    try {
      this.current(generation);
      const side: number = Math.max(1, Math.floor(Math.min(preview.width, preview.height) / zoom));
      const x: number = Math.round((preview.width - side) * xPercent / 100);
      const y: number = Math.round((preview.height - side) * yPercent / 100);
      const edge: number = Math.min(AVATAR_EDGE, side);
      source = image.createImageSource(preview.data);
      pixels = await source.createPixelMap({ desiredRegion: { x: x, y: y, size: { width: side, height: side } },
        desiredSize: { width: edge, height: edge }, cropAndScaleStrategy: image.CropAndScaleStrategy.CROP_FIRST,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888 });
      for (const quality of [88, 78, 65, 50, 35]) {
        this.current(generation);
        const data: ArrayBuffer = await encodeJpeg(pixels, quality);
        this.current(generation);
        if (data.byteLength <= MAX_AVATAR_BYTES) {
          const upload: AvatarUpload = new AvatarUpload();
          upload.data = data;
          return upload;
        }
      }
      throw processingFailure();
    } catch (error) {
      if (error instanceof GameFailure) {
        throw error;
      }
      throw processingFailure();
    } finally {
      await releaseAvatarPixelMap(pixels);
      await releaseSource(source);
    }
  }

  dispose(): void {
    this.disposed = true;
    this.generation++;
    this.uri = '';
    this.prepared = null;
  }
}

/** UIAbility-triggered system selection. Reading starts later in the mounted crop content. */
export class AvatarEditor {
  private generation: number = 0;
  private selection: AvatarSelection | null = null;

  async pick(): Promise<AvatarSelection | null> {
    const generation: number = ++this.generation;
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 1;
    options.isPhotoTakingSupported = false;
    options.mimeTypeFilter = { mimeTypeArray: ['image/jpeg', 'image/png', 'image/webp'] };
    options.fileSizeFilter = { filterOperator: photoAccessHelper.FilterOperator.LESS_THAN_OR_EQUAL_TO,
      fileSize: MAX_ORIGINAL_BYTES };
    try {
      const result: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(options);
      if (generation !== this.generation || result.photoUris.length === 0) {
        return null;
      }
      // Cancelling a re-selection must keep the current crop usable.
      const previous: AvatarSelection | null = this.selection;
      this.selection = new AvatarSelection(result.photoUris[0]);
      previous?.dispose();
      return this.selection;
    } catch {
      if (generation !== this.generation) {
        return null;
      }
      throw processingFailure();
    }
  }

  dispose(): void {
    this.generation++;
    this.selection?.dispose();
    this.selection = null;
  }
}

/** The returned PixelMap is owned by its mounted Image component. */
export async function decodeAvatarImage(data: ArrayBuffer): Promise<image.PixelMap> {
  const source: image.ImageSource = image.createImageSource(data);
  try {
    const info: image.ImageInfo = await source.getImageInfo();
    const scale: number = Math.min(1, AVATAR_EDGE / Math.max(info.size.width, info.size.height));
    return await source.createPixelMap({ desiredSize: { width: Math.max(1, Math.round(info.size.width * scale)),
      height: Math.max(1, Math.round(info.size.height * scale)) } });
  } finally {
    await source.release();
  }
}
