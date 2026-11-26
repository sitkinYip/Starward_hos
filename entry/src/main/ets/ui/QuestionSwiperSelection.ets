/** Tracks ArkUI's displayed index separately from the owning question's selected ID. */
export class QuestionSwiperSelection {
  private pages: string[] = [];
  private displayedIndex: number = 0;
  private requestedIndex: number = -1;
  private requestedId: string = '';
  private animationTarget: number = -1;
  private gestureFrom: string = '';
  private gestureTo: string = '';

  reset(pages: string[], selected: string): number {
    this.pages = pages.slice();
    this.displayedIndex = Math.max(0, pages.indexOf(selected));
    this.clearRequest();
    this.clearGesture();
    return this.displayedIndex;
  }

  updatePages(pages: string[]): void {
    if (this.pages.length === pages.length && this.pages.every((id: string, index: number) => id === pages[index])) {
      return;
    }
    if (pages[this.displayedIndex] !== this.pages[this.displayedIndex] ||
      (this.gestureTo.length > 0 && pages.indexOf(this.gestureTo) !== this.pages.indexOf(this.gestureTo))) {
      this.clearGesture();
    }
    if (this.requestedIndex >= 0 && pages[this.requestedIndex] !== this.requestedId) {
      this.clearRequest();
    }
    // With looping disabled ArkUI returns to the first item if the old index is out of range.
    if (this.displayedIndex >= pages.length) { this.displayedIndex = 0; }
    this.pages = pages.slice();
  }

  displayedId(): string { return this.pages[this.displayedIndex] ?? ''; }

  isMoving(): boolean { return this.requestedIndex >= 0; }

  awaits(index: number): boolean { return index >= 0 && index === this.requestedIndex; }

  clearGesture(): void {
    this.gestureFrom = '';
    this.gestureTo = '';
  }

  followGesture(from: number, to: number, selected: string): boolean {
    if (this.isMoving() || from !== this.displayedIndex || this.pages[from] !== selected ||
      Math.abs(to - from) !== 1 || this.pages[to] === undefined) { return false; }
    this.gestureFrom = selected;
    this.gestureTo = this.pages[to];
    return true;
  }

  /** While one native move is in flight, let the next selection coalesce at its destination. */
  request(selected: string): number {
    const target: number = this.pages.indexOf(selected);
    if (target < 0 || target === this.displayedIndex || this.isMoving()) { return -1; }
    this.clearGesture();
    this.requestedIndex = target;
    this.requestedId = selected;
    return target;
  }

  isAdjacent(index: number): boolean { return Math.abs(index - this.displayedIndex) === 1; }

  animationStarted(from: number, to: number): void {
    if (from === this.displayedIndex && this.awaits(to)) { this.animationTarget = to; }
  }

  animationEnded(index: number): boolean {
    if (!this.awaits(index) || index !== this.animationTarget) { return false; }
    this.finishMove(index);
    return true;
  }

  private clearRequest(): void {
    this.requestedIndex = -1;
    this.requestedId = '';
    this.animationTarget = -1;
  }

  private finishMove(index: number): void {
    this.displayedIndex = index;
    this.clearRequest();
  }

  /** Only a gesture bound to the still-owned starting question may change selection. */
  observe(index: number, selected: string, swipeEnabled: boolean): string {
    if (index < 0 || index >= this.pages.length) { return ''; }
    if (this.isMoving()) {
      if (this.awaits(index)) { this.finishMove(index); }
      return '';
    }
    const destination: string = this.pages[index];
    const fromGesture: boolean = swipeEnabled && this.gestureFrom === selected && this.gestureTo === destination &&
      this.displayedId() === selected && this.isAdjacent(index);
    this.displayedIndex = index;
    this.clearGesture();
    return fromGesture ? destination : '';
  }
}
