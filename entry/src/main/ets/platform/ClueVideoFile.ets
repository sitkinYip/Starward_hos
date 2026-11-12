import { url } from '@kit.ArkTS';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { http } from '@kit.NetworkKit';
import { AppEnvironment } from './AppEnvironment';

const WEB_ORIGIN: string = 'https://sitkin.top/';
const MAX_BYTES: number = 16 * 1024 * 1024;
const CACHE_PREFIX: string = 'starward-clue-video-';
const CACHE_FILE: string = 'clip.mp4';

class VideoTarget {
  readonly href: string;
  readonly caData?: string;

  constructor(href: string, caData?: string) { this.href = href; this.caData = caData; }
}

function publicHost(host: string): boolean {
  return host.length <= 253 &&
    /^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(host) &&
    !/\.[0-9]+$/.test(host) && !/\.(localhost|local|localdomain|internal|lan|home|test|invalid|onion)$/.test(host) &&
    host !== 'home.arpa' && !host.endsWith('.home.arpa');
}

function targetFor(source: string): VideoTarget {
  if (source.length === 0 || source.length > 8192 || /[\s\\\u0000-\u001f\u007f]/.test(source)) {
    throw new Error('Invalid video source');
  }
  const endpoint: string = AppEnvironment.endpoint;
  if (endpoint === 'https://127.0.0.1:18443' && AppEnvironment.configurationError === '' &&
    AppEnvironment.caData.length > 0 && source.startsWith(endpoint) &&
    /^\/__starward_test_media\/[a-z0-9-]+\.mp4$/.test(source.slice(endpoint.length))) {
    return new VideoTarget(source, AppEnvironment.caData);
  }
  if ((!/^https:\/\//i.test(source) && (!source.startsWith('/') || source.startsWith('//'))) ||
    /^https:\/\/[^/?#]*@/i.test(source)) {
    throw new Error('Invalid video source');
  }
  const target: url.URL = url.URL.parseURL(source, WEB_ORIGIN);
  const host: string = target.hostname.toLowerCase().replace(/\.$/, '');
  if (target.protocol !== 'https:' || target.username !== '' || target.password !== '' ||
    (target.port !== '' && target.port !== '443') || !publicHost(host)) {
    throw new Error('Invalid video source');
  }
  target.hash = '';
  return new VideoTarget(target.href);
}

function removeScratch(directory: string): void {
  try {
    if (!fileIo.lstatSync(directory).isDirectory()) { return; }
    try { fileIo.unlinkSync(`${directory}/${CACHE_FILE}`); } catch { /* The file may not exist yet. */ }
    if (fileIo.listFileSync(directory).length === 0) { fileIo.rmdirSync(directory); }
  } catch {
    // A new ability instance retries abandoned scratch cleanup at startup.
  }
}

export function pruneAbandonedClueVideos(cacheDir: string): void {
  if (cacheDir.length === 0) { return; }
  try {
    const names: string[] = fileIo.listFileSync(cacheDir);
    names.filter((name: string) => /^starward-clue-video-[a-z0-9]{6}$/i.test(name))
      .forEach((name: string) => removeScratch(`${cacheDir}/${name}`));
  } catch {
    // Scratch cleanup never gates ability startup.
  }
}

export interface ClueVideoFile {
  readonly uri: string;
  readonly width: number;
  readonly height: number;
  release(): void;
}

class VideoDimensions {
  width: number;
  height: number;

  constructor(width: number = 0, height: number = 0) { this.width = width; this.height = height; }
}

class ScratchClueVideoFile implements ClueVideoFile {
  readonly uri: string;
  readonly width: number;
  readonly height: number;
  private readonly directory: string;
  private released: boolean = false;

  constructor(directory: string, path: string, dimensions: VideoDimensions) {
    this.directory = directory;
    this.uri = fileUri.getUriFromPath(path);
    this.width = dimensions.width;
    this.height = dimensions.height;
  }

  release(): void {
    if (this.released) { return; }
    this.released = true;
    removeScratch(this.directory);
  }
}

async function videoDimensions(fd: number, size: number): Promise<VideoDimensions> {
  let extractor: media.AVMetadataExtractor | undefined;
  try {
    extractor = await media.createAVMetadataExtractor();
    extractor.fdSrc = { fd: fd, offset: 0, length: size };
    const metadata: media.AVMetadata | undefined = await extractor.fetchMetadataWithTimeout(1500);
    const width: number = Number(metadata?.videoWidth);
    const height: number = Number(metadata?.videoHeight);
    if (!Number.isSafeInteger(width) || !Number.isSafeInteger(height) || width <= 0 || height <= 0) {
      return new VideoDimensions();
    }
    const rotation: number = Math.abs(Number(metadata?.videoOrientation));
    return rotation === 90 || rotation === 270 ? new VideoDimensions(height, width) : new VideoDimensions(width, height);
  } catch {
    return new VideoDimensions();
  } finally {
    if (extractor !== undefined) {
      try { await extractor.release(); } catch { /* Metadata is optional. */ }
    }
  }
}

function isMp4(bytes: ArrayBuffer): boolean {
  if (bytes.byteLength < 16 || bytes.byteLength > MAX_BYTES) { return false; }
  const prefix: Uint8Array = new Uint8Array(bytes, 0, 8);
  // ISO base media file type box. The native player checks and decodes the rest of the file.
  return prefix[4] === 0x66 && prefix[5] === 0x74 && prefix[6] === 0x79 && prefix[7] === 0x70;
}

class VideoLoad {
  private request: http.HttpRequest | undefined;

  async read(target: VideoTarget): Promise<ArrayBuffer> {
    const task: http.HttpRequest = http.createHttp();
    this.request = task;
    try {
      task.enableAutoCookie(false);
      const response: http.HttpResponse = await task.request(target.href, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'video/mp4', 'Referer': WEB_ORIGIN },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingCache: false,
        usingProxy: false,
        maxRedirects: 0,
        maxLimit: MAX_BYTES,
        connectTimeout: AppEnvironment.timeoutMs,
        readTimeout: AppEnvironment.timeoutMs,
        caData: target.caData,
        remoteValidation: 'system',
        enablePartialChain: false,
        reuseConnections: false
      });
      if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer) || !isMp4(response.result)) {
        throw new Error('Invalid video response');
      }
      return response.result;
    } finally {
      this.destroyRequest();
    }
  }

  destroyRequest(): void {
    const request: http.HttpRequest | undefined = this.request;
    this.request = undefined;
    try { request?.destroy(); } catch { /* The native error may include the media URL. */ }
  }
}

/** A single cancelable fetch. After load resolves, the caller owns the transient file. */
export class ClueVideoFileLoader {
  private readonly cacheDir: string;
  private pending: VideoLoad | undefined;

  constructor(cacheDir: string) { this.cacheDir = cacheDir; }

  cancel(): void {
    const previous: VideoLoad | undefined = this.pending;
    this.pending = undefined;
    previous?.destroyRequest();
  }

  async load(source: string): Promise<ClueVideoFile> {
    this.cancel();
    const operation: VideoLoad = new VideoLoad();
    this.pending = operation;
    let directory: string = '';
    try {
      if (this.cacheDir.length === 0) { throw new Error('Missing scratch directory'); }
      const data: ArrayBuffer = await operation.read(targetFor(source));
      if (this.pending !== operation) { throw new Error('Cancelled video load'); }
      directory = await fileIo.mkdtemp(`${this.cacheDir}/${CACHE_PREFIX}XXXXXX`);
      if (this.pending !== operation) { throw new Error('Cancelled video load'); }
      const path: string = `${directory}/${CACHE_FILE}`;
      const file: fileIo.File = await fileIo.open(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.NOFOLLOW);
      let dimensions: VideoDimensions;
      try {
        if (this.pending !== operation || await fileIo.write(file.fd, data) !== data.byteLength ||
          this.pending !== operation) {
          throw new Error('Incomplete video load');
        }
        dimensions = await videoDimensions(file.fd, data.byteLength);
      } finally {
        await fileIo.close(file);
      }
      if (this.pending !== operation) { throw new Error('Cancelled video load'); }
      return new ScratchClueVideoFile(directory, path, dimensions);
    } catch {
      if (directory.length > 0) { removeScratch(directory); }
      throw new Error('视频加载失败，请重试。');
    } finally {
      if (this.pending === operation) { this.pending = undefined; }
    }
  }
}
