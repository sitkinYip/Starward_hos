import { QuestionImageResult } from './QuestionImageLoader';

const MAX_CACHED_BYTES: number = 48 * 1024 * 1024;
const MAX_CACHED_IMAGES: number = 24;

/** The current gameplay page retains recent, fully decoded images at the shared 2048 px limit. */
export class QuestionImageCache {
  private readonly images: Map<string, QuestionImageResult> = new Map();
  private readonly currentOwner: () => string;
  private readonly maxBytes: number;
  private readonly maxEntries: number;
  private owner: string = '';
  private revision: number = 0;
  private bytes: number = 0;

  constructor(owner: () => string, maxBytes: number = MAX_CACHED_BYTES, maxEntries: number = MAX_CACHED_IMAGES) {
    this.currentOwner = owner;
    this.maxBytes = maxBytes;
    this.maxEntries = maxEntries;
  }

  validateOwner(): void {
    const owner: string = this.currentOwner();
    if (owner !== this.owner) {
      this.clear();
      this.owner = owner;
    }
  }

  version(): number {
    this.validateOwner();
    return this.revision;
  }

  acquire(source: string): QuestionImageResult | undefined {
    this.validateOwner();
    const value: QuestionImageResult | undefined = this.images.get(source);
    if (value === undefined) { return undefined; }
    // Map order tracks the least recently used image first.
    this.images.delete(source);
    this.images.set(source, value);
    return value.retain();
  }

  remember(source: string, value: QuestionImageResult, version: number): void {
    this.validateOwner();
    if (version !== this.revision || this.owner.length === 0 || this.images.has(source) ||
      value.byteSize > this.maxBytes) { return; }
    this.images.set(source, value.retain());
    this.bytes += value.byteSize;
    while (this.bytes > this.maxBytes || this.images.size > this.maxEntries) {
      const oldest: string = this.images.keys().next().value;
      const discarded: QuestionImageResult | undefined = this.images.get(oldest);
      if (discarded === undefined) { break; }
      this.images.delete(oldest);
      this.bytes -= discarded.byteSize;
      discarded.release();
    }
  }

  clear(): void {
    this.revision++;
    this.images.forEach((value: QuestionImageResult) => { value.release(); });
    this.images.clear();
    this.bytes = 0;
  }
}
