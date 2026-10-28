/** Native pull-to-refresh. The gesture flag is separate from ViewModel busy state. */
@ComponentV2
export struct StarwardRefresh {
  @Param refreshEnabled: boolean = true;
  @Param request: () => Promise<void> = async () => {};
  @Event requestFailed: (error: Object) => void = () => {};
  @BuilderParam content: () => void;
  @Local private uiRefreshing: boolean = false;
  private active: boolean = false;
  private mounted: boolean = false;
  private generation: number = 0;

  aboutToAppear(): void {
    this.mounted = true;
    this.generation++;
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.generation++;
    this.active = false;
    this.uiRefreshing = false;
  }

  private async refresh(): Promise<void> {
    if (this.active) {
      return;
    }
    if (!this.refreshEnabled || !this.mounted) {
      this.uiRefreshing = false;
      return;
    }
    const generation: number = this.generation;
    this.active = true;
    this.uiRefreshing = true;
    try {
      // The owner retains business errors and account-generation checks.
      const operation: Promise<void> = this.request();
      await operation;
    } catch (error) {
      if (this.mounted && generation === this.generation) {
        this.requestFailed(error as Object);
      }
    } finally {
      if (this.mounted && generation === this.generation) {
        this.active = false;
        this.uiRefreshing = false;
      }
    }
  }

  build() {
    Refresh({ refreshing: this.uiRefreshing!! }) {
      this.content()
    }.width('100%').height('100%').pullToRefresh(this.refreshEnabled)
      .onRefreshing(() => { this.refresh(); })
  }
}
