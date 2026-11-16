export type NarrativeKind = 'letter' | 'bless';
export type NarrativeLetterVariant = 'modern' | 'classical' | 'magic';
export type NarrativeParagraphAlign = 'left' | 'center' | 'right' | 'top' | 'bottom';

export class NarrativeParagraph {
  content: string = '';
  align: NarrativeParagraphAlign = 'left';
  delayMs: number = 0;
  audioUrl: string = '';
}

export class NarrativeLetter {
  variant: NarrativeLetterVariant = 'modern';
  from: string = '';
  description: string = '';
  hintText: string = '点击开启信件';
  paragraphs: NarrativeParagraph[] = [];
  backgroundImages: string[] = [];
  pageBackgroundUrl: string = '';
  mainAudioUrl: string = '';
  typingSpeedMs: number = 60;
}

export class NarrativeBlessLine {
  text: string = '';
  durationMs: number = 3000;
  audioUrl: string = '';
}

export class NarrativeBless {
  from: string = '';
  phrases: NarrativeBlessLine[] = [];
  closingLines: NarrativeBlessLine[] = [];
  mainAudioUrl: string = '';
}

export class NarrativeContent {
  id: string = '';
  kind: NarrativeKind = 'letter';
  title: string = '';
  letter: NarrativeLetter | null = null;
  bless: NarrativeBless | null = null;

  hasPresentation(): boolean {
    return this.kind === 'letter' ? this.letter !== null : this.bless !== null;
  }
}
