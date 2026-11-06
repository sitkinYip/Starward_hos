import { image } from '@kit.ImageKit';

export interface QuestionImageResponse {
  status: number;
  bytes: ArrayBuffer | undefined;
}

export interface QuestionImageMetadata {
  widthPx: number;
  heightPx: number;
  mimeType: string;
}

export interface QuestionImageRequestHandle {
  read(target: string): Promise<QuestionImageResponse>;
  destroy(): void;
}

export interface QuestionImagePixelsHandle {
  metadata(): Promise<QuestionImageMetadata>;
  flip(horizontal: boolean, vertical: boolean): Promise<void>;
  rotate(degrees: number): Promise<void>;
  release(): Promise<void>;
  nativeValue(): image.PixelMap;
}

export interface QuestionImageSourceHandle {
  metadata(): Promise<QuestionImageMetadata>;
  orientation(): Promise<string>;
  decode(widthPx: number, heightPx: number): Promise<QuestionImagePixelsHandle>;
  release(): Promise<void>;
}

/** Per-loader resources; no global Kit mutation or environment-controlled factory. */
export interface QuestionImageIO {
  resolveSource(source: string): string;
  createRequest(): QuestionImageRequestHandle;
  createSource(bytes: ArrayBuffer): QuestionImageSourceHandle;
}
