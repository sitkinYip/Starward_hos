import { url } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { AppEnvironment } from './AppEnvironment';
import { QuestionImageIO, QuestionImageMetadata, QuestionImagePixelsHandle, QuestionImageRequestHandle,
  QuestionImageResponse, QuestionImageSourceHandle } from './QuestionImageIO';

const WEB_ORIGIN: string = 'https://sitkin.top/';
const MAX_BYTES: number = 5 * 1024 * 1024;
const MAX_ORIGINAL_EDGE: number = 16384;
const MAX_ORIGINAL_PIXELS: number = 40 * 1024 * 1024;
const MAX_DECODED_EDGE: number = 2048;
const IMAGE_FIXTURE_ORIGIN: string = 'https://127.0.0.1:18443';
const IMAGE_FIXTURE_PATHS: string[] = [
  'auto-clue-a.png', 'auto-clue-b.png',
  'quest-bg-session.png', 'quest-bg-level.png', 'quest-bg-missing.png', 'quest-bg-slow.png'
];

function fixtureImageCa(target: string): string | undefined {
  if (AppEnvironment.endpoint === IMAGE_FIXTURE_ORIGIN && AppEnvironment.probeTls &&
    AppEnvironment.configurationError === '' && AppEnvironment.caData.length > 0 &&
    IMAGE_FIXTURE_PATHS.some((file: string) => target === IMAGE_FIXTURE_ORIGIN + '/__starward_fixture_media/' + file)) {
    return AppEnvironment.caData;
  }
  return undefined;
}

export class QuestionImageResult {
  readonly naturalWidthPx: number;
  readonly naturalHeightPx: number;
  readonly decodedWidthPx: number;
  readonly decodedHeightPx: number;
  readonly detectedMime: string;
  readonly byteSize: number;
  private readonly handle: QuestionImagePixelsHandle;
  private references: number = 1;

  constructor(handle: QuestionImagePixelsHandle, naturalWidthPx: number, naturalHeightPx: number,
    decodedWidthPx: number, decodedHeightPx: number, detectedMime: string) {
    this.handle = handle;
    this.naturalWidthPx = naturalWidthPx;
    this.naturalHeightPx = naturalHeightPx;
    this.decodedWidthPx = decodedWidthPx;
    this.decodedHeightPx = decodedHeightPx;
    this.detectedMime = detectedMime;
    this.byteSize = Math.max(handle.bytesPerRow(), decodedWidthPx * 4) * decodedHeightPx;
  }

  get pixels(): image.PixelMap { return this.handle.nativeValue(); }

  /** The loader, each displaying consumer and the cache own separate references. */
  retain(): QuestionImageResult {
    this.references++;
    return this;
  }

  async release(): Promise<void> {
    if (this.references > 0 && --this.references === 0) { await releasePixels(this.handle); }
  }
}

export class QuestionImageFailure extends Error {
  readonly cancelled: boolean;
  readonly httpStatus: number;

  constructor(cancelled: boolean = false, httpStatus: number = 0) {
    super(cancelled ? '图片加载已取消。' : '图片加载失败，请重试。');
    this.name = 'QuestionImageFailure';
    this.cancelled = cancelled;
    this.httpStatus = httpStatus;
  }
}

/** One native request; both cancellation and final cleanup may reach destroy(). */
class QuestionImageRequest {
  readonly task: QuestionImageRequestHandle;
  private destroyed: boolean = false;

  constructor(task: QuestionImageRequestHandle) { this.task = task; }

  destroy(): void {
    if (this.destroyed) {
      return;
    }
    this.destroyed = true;
    try {
      this.task.destroy();
    } catch {
      // Never expose native error messages, which can contain protected URLs.
    }
  }
}

function publicIpv4(address: string): boolean {
  const parts: string[] = address.split('.');
  if (parts.length !== 4) {
    return false;
  }
  const values: number[] = [];
  for (const part of parts) {
    if (!/^(0|[1-9][0-9]{0,2})$/.test(part)) {
      return false;
    }
    const value: number = Number(part);
    if (value > 255) {
      return false;
    }
    values.push(value);
  }
  const first: number = values[0];
  const second: number = values[1];
  const third: number = values[2];
  return first !== 0 && first !== 10 && first !== 127 && first < 224 &&
    !(first === 100 && second >= 64 && second <= 127) &&
    !(first === 169 && second === 254) &&
    !(first === 172 && second >= 16 && second <= 31) &&
    !(first === 192 && (second === 168 || (second === 0 && (third === 0 || third === 2)) ||
      (second === 88 && third === 99))) &&
    !(first === 198 && (second === 18 || second === 19 || (second === 51 && third === 100))) &&
    !(first === 203 && second === 0 && third === 113);
}

function publicAddress(address: string): boolean {
  if (address.indexOf(':') < 0) {
    return publicIpv4(address);
  }
  // Conservatively accept ordinary global-unicast IPv6 only, not mapped/local/zone addresses.
  if (!/^[0-9a-f:]+$/i.test(address)) {
    return false;
  }
  const sides: string[] = address.toLowerCase().split('::');
  if (sides.length > 2) {
    return false;
  }
  const left: string[] = sides[0] === '' ? [] : sides[0].split(':');
  const right: string[] = sides.length === 1 || sides[1] === '' ? [] : sides[1].split(':');
  const groups: string[] = left.concat(right);
  if ((sides.length === 1 && groups.length !== 8) || (sides.length === 2 && groups.length >= 8)) {
    return false;
  }
  for (const group of groups) {
    if (!/^[0-9a-f]{1,4}$/.test(group)) {
      return false;
    }
  }
  const first: number = left.length === 0 ? 0 : parseInt(left[0], 16);
  const second: number = left.length < 2 ? 0 : parseInt(left[1], 16);
  return first >= 0x2000 && first <= 0x3fff && first !== 0x2002 && first !== 0x3fff &&
    !(first === 0x2001 && (second < 0x0200 || second === 0x0db8));
}

/** @throws {Error} Invalid URLs are handled by the owning load operation. */
function imageTarget(source: string): url.URL {
  if (source.length === 0 || source.length > 8192 || /[\s\\\u0000-\u001f\u007f]/.test(source) ||
    (!/^https:\/\//i.test(source) && (!source.startsWith('/') || source.startsWith('//')))) {
    throw new QuestionImageFailure();
  }
  const target: url.URL = url.URL.parseURL(source, WEB_ORIGIN);
  const host: string = target.hostname.toLowerCase().replace(/\.$/, '');
  if (target.protocol !== 'https:' || target.username !== '' || target.password !== '' ||
    (target.port !== '' && target.port !== '443') || /^https:\/\/[^/?#]*@/i.test(source)) {
    throw new QuestionImageFailure();
  }
  if (host.indexOf(':') >= 0 || /^[0-9.]+$/.test(host)) {
    if (!publicAddress(host.replace(/^\[/, '').replace(/\]$/, ''))) {
      throw new QuestionImageFailure();
    }
  } else {
    if (host.indexOf('.') < 0 || !/^[a-z0-9.-]+$/.test(host) || /\.[0-9]+$/.test(host) ||
      /(^|\.)(localhost|local|localdomain|internal|lan|home|test|invalid|onion)$/.test(host) ||
      host === 'home.arpa' || host.endsWith('.home.arpa')) {
      throw new QuestionImageFailure();
    }
    const labels: string[] = host.split('.');
    for (const label of labels) {
      if (label.length === 0 || label.length > 63 || label.startsWith('-') || label.endsWith('-')) {
        throw new QuestionImageFailure();
      }
    }
  }
  target.hash = '';
  return target;
}

function detectedMime(bytes: Uint8Array): string {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e &&
    bytes[3] === 0x47 && bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a) {
    return 'image/png';
  }
  if (bytes.length >= 12 && bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 &&
    bytes[3] === 0x46 && bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) {
    return 'image/webp';
  }
  throw new QuestionImageFailure();
}

function validSize(width: number, height: number, edge: number, pixels: number): boolean {
  return Number.isInteger(width) && Number.isInteger(height) && width > 0 && height > 0 &&
    width <= edge && height <= edge && width * height <= pixels;
}

class NativeQuestionImageRequest implements QuestionImageRequestHandle {
  private readonly task: http.HttpRequest = http.createHttp();

  /** @throws {Error} The loader normalizes HTTP failures after its resource cleanup. */
  async read(target: string): Promise<QuestionImageResponse> {
    this.task.enableAutoCookie(false);
    const response: http.HttpResponse = await this.task.request(target, {
      method: http.RequestMethod.GET,
      header: { 'Accept': 'image/jpeg,image/png,image/webp', 'Referer': WEB_ORIGIN },
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      usingCache: false,
      usingProxy: false,
      connectTimeout: 15000,
      readTimeout: 15000,
      maxLimit: MAX_BYTES,
      maxRedirects: 0,
      remoteValidation: 'system',
      caData: fixtureImageCa(target),
      enablePartialChain: false
    });
    return { status: response.responseCode,
      bytes: response.result instanceof ArrayBuffer ? response.result : undefined };
  }

  destroy(): void { this.task.destroy(); }
}

function metadata(info: image.ImageInfo): QuestionImageMetadata {
  return { widthPx: info.size.width, heightPx: info.size.height, mimeType: info.mimeType };
}

class NativeQuestionImagePixels implements QuestionImagePixelsHandle {
  private readonly pixels: image.PixelMap;

  constructor(pixels: image.PixelMap) { this.pixels = pixels; }

  bytesPerRow(): number { return this.pixels.getBytesNumberPerRow(); }
  async metadata(): Promise<QuestionImageMetadata> { return metadata(await this.pixels.getImageInfo()); }
  async flip(horizontal: boolean, vertical: boolean): Promise<void> { await this.pixels.flip(horizontal, vertical); }
  async rotate(degrees: number): Promise<void> { await this.pixels.rotate(degrees); }
  async release(): Promise<void> { await this.pixels.release(); }
  nativeValue(): image.PixelMap { return this.pixels; }
}

class NativeQuestionImageSource implements QuestionImageSourceHandle {
  private readonly source: image.ImageSource;

  /** @throws {Error} Invalid source bytes are handled by the owning load operation. */
  constructor(bytes: ArrayBuffer) { this.source = image.createImageSource(bytes); }

  async metadata(): Promise<QuestionImageMetadata> { return metadata(await this.source.getImageInfo()); }
  /** @throws {Error} Missing EXIF is handled as an unrotated image by the loader. */
  async orientation(): Promise<string> { return await this.source.getImageProperty(image.PropertyKey.ORIENTATION); }
  async decode(widthPx: number, heightPx: number): Promise<QuestionImagePixelsHandle> {
    const pixels: image.PixelMap = await this.source.createPixelMap({
      desiredSize: { width: widthPx, height: heightPx },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: true
    });
    return new NativeQuestionImagePixels(pixels);
  }
  async release(): Promise<void> { await this.source.release(); }
}

class NativeQuestionImageIO implements QuestionImageIO {
  /** @throws {Error} The loader maps source policy failures to its fixed product message. */
  resolveSource(source: string): string { return fixtureImageCa(source) === undefined ? imageTarget(source).href : source; }
  createRequest(): QuestionImageRequestHandle { return new NativeQuestionImageRequest(); }
  /** @throws {Error} Source allocation failures are handled by the owning load operation. */
  createSource(bytes: ArrayBuffer): QuestionImageSourceHandle { return new NativeQuestionImageSource(bytes); }
}

async function releaseSource(source: QuestionImageSourceHandle): Promise<void> {
  try {
    await source.release();
  } catch {
    // Cleanup has no product-visible native error details.
  }
}

async function releasePixels(pixels: QuestionImagePixelsHandle): Promise<void> {
  try {
    await pixels.release();
  } catch {
    // Native cleanup failures must not expose details of private media.
  }
}

/** Per-mounted-image owner. No account state, disk cache, backend CA, or shared request/cache. */
export class QuestionImageLoader {
  private readonly io: QuestionImageIO;
  private generation: number = 0;
  private request: QuestionImageRequest | undefined = undefined;

  constructor(io: QuestionImageIO = new NativeQuestionImageIO()) { this.io = io; }

  cancel(): void {
    this.generation++;
    const request: QuestionImageRequest | undefined = this.request;
    this.request = undefined;
    if (request !== undefined) {
      request.destroy();
    }
  }

  private assertCurrent(generation: number): void {
    if (generation !== this.generation) {
      throw new QuestionImageFailure(true);
    }
  }

  private async orient(pixels: QuestionImagePixelsHandle, orientation: string, generation: number): Promise<void> {
    if (orientation === 'Top-right' || orientation === '2') {
      await pixels.flip(true, false);
    } else if (orientation === 'Bottom-right' || orientation === '3') {
      await pixels.rotate(180);
    } else if (orientation === 'Bottom-left' || orientation === '4') {
      await pixels.flip(false, true);
    } else if (orientation === 'Left-top' || orientation === '5') {
      await pixels.flip(true, false);
      this.assertCurrent(generation);
      await pixels.rotate(270);
    } else if (orientation === 'Right-top' || orientation === '6') {
      await pixels.rotate(90);
    } else if (orientation === 'Right-bottom' || orientation === '7') {
      await pixels.flip(true, false);
      this.assertCurrent(generation);
      await pixels.rotate(90);
    } else if (orientation === 'Left-bottom' || orientation === '8') {
      await pixels.rotate(270);
    }
    this.assertCurrent(generation);
  }

  async load(source: string, maxEdgePx: number = MAX_DECODED_EDGE): Promise<QuestionImageResult> {
    this.cancel();
    const generation: number = this.generation;
    let request: QuestionImageRequest | undefined = undefined;
    let imageSource: QuestionImageSourceHandle | undefined = undefined;
    let pixels: QuestionImagePixelsHandle | undefined = undefined;
    let original: QuestionImageMetadata | undefined = undefined;
    let decoded: QuestionImageMetadata | undefined = undefined;
    let mime: string = '';
    let swapped: boolean = false;
    let failed: boolean = false;
    let status: number = 0;
    try {
      if (!Number.isFinite(maxEdgePx) || maxEdgePx < 1) {
        throw new QuestionImageFailure();
      }
      const edge: number = Math.min(MAX_DECODED_EDGE, Math.floor(maxEdgePx));
      const target: string = this.io.resolveSource(source);
      // Hostnames use system DNS/TLS. URL-local-address rejection is not DNS-rebinding protection.
      request = new QuestionImageRequest(this.io.createRequest());
      this.request = request;
      const response: QuestionImageResponse = await request.task.read(target);
      status = response.status;
      this.assertCurrent(generation);
      request.destroy();
      if (this.request === request) {
        this.request = undefined;
      }
      if (response.status !== 200 || response.bytes === undefined ||
        response.bytes.byteLength === 0 || response.bytes.byteLength > MAX_BYTES) {
        throw new QuestionImageFailure();
      }
      mime = detectedMime(new Uint8Array(response.bytes));
      imageSource = this.io.createSource(response.bytes);
      original = await imageSource.metadata();
      this.assertCurrent(generation);
      if (original.mimeType !== mime || !validSize(original.widthPx, original.heightPx,
        MAX_ORIGINAL_EDGE, MAX_ORIGINAL_PIXELS)) {
        throw new QuestionImageFailure();
      }
      let orientation: string = '';
      try {
        orientation = await imageSource.orientation();
      } catch {
        // Images without EXIF orientation are valid. No location metadata is requested.
      }
      this.assertCurrent(generation);
      const scale: number = Math.min(1, edge / Math.max(original.widthPx, original.heightPx));
      pixels = await imageSource.decode(Math.max(1, Math.floor(original.widthPx * scale)),
        Math.max(1, Math.floor(original.heightPx * scale)));
      this.assertCurrent(generation);
      await this.orient(pixels, orientation, generation);
      this.assertCurrent(generation);
      decoded = await pixels.metadata();
      this.assertCurrent(generation);
      if (!validSize(decoded.widthPx, decoded.heightPx, edge, edge * edge)) {
        throw new QuestionImageFailure();
      }
      swapped = ['Left-top', 'Right-top', 'Right-bottom', 'Left-bottom', '5', '6', '7', '8']
        .includes(orientation);
    } catch {
      failed = true;
    } finally {
      if (request !== undefined) {
        request.destroy();
        if (this.request === request) {
          this.request = undefined;
        }
      }
      // ImageSource is never released while one of its asynchronous operations is pending.
      if (imageSource !== undefined) {
        await releaseSource(imageSource);
      }
    }
    if (failed || pixels === undefined || original === undefined || decoded === undefined || generation !== this.generation) {
      if (pixels !== undefined) {
        await releasePixels(pixels);
      }
      throw new QuestionImageFailure(generation !== this.generation, status);
    }
    try {
      // No await on success: ownership transfers after source cleanup.
      return new QuestionImageResult(pixels, swapped ? original.heightPx : original.widthPx,
        swapped ? original.widthPx : original.heightPx, decoded.widthPx, decoded.heightPx, mime);
    } catch {
      await releasePixels(pixels);
      throw new QuestionImageFailure(generation !== this.generation, status);
    }
  }
}
