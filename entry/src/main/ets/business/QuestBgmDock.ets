export const QUEST_BGM_SIZE: number = 56;
export const QUEST_BGM_MARGIN: number = 12;

export function questBgmRatio(value: number, fallback: number = 1): number {
  return Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : fallback;
}

export function questBgmTravel(extent: number, startInset: number, endInset: number): number {
  return Math.max(0, extent - startInset - endInset - QUEST_BGM_SIZE - 2 * QUEST_BGM_MARGIN);
}

export function questBgmCoordinate(ratio: number, extent: number, startInset: number, endInset: number): number {
  return startInset + QUEST_BGM_MARGIN + questBgmRatio(ratio) * questBgmTravel(extent, startInset, endInset);
}

export class QuestBgmPosition {
  readonly x: number;
  readonly y: number;

  constructor(x: number = 1, y: number = 1) {
    this.x = questBgmRatio(x) < 0.5 ? 0 : 1;
    this.y = questBgmRatio(y);
  }
}
