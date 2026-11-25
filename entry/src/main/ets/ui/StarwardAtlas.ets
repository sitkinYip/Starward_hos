/** Native geometry follows the frozen Web CelestialAtlas proportions. */
@ComponentV2
export struct StarwardAtlas {
  @Param atlasSize: number = 210;
  @Param renderX: number = 0;
  @Param renderY: number = 0;

  // CSS orbit percentages use the padding box inside its 1vp border.
  @Builder
  outerOrbit() {
    Stack() {
      Circle().width(this.atlasSize * 0.96).height(this.atlasSize * 0.96).fill(Color.Transparent)
        .stroke($r('app.color.accent_muted')).strokeWidth(1)
      Circle().width(this.atlasSize * 0.96 - 20).height(this.atlasSize * 0.96 - 20).fill(Color.Transparent)
        .stroke($r('app.color.accent_muted')).strokeWidth(1).strokeDashArray([2, 3])
      Circle().width(8).height(8).fill($r('app.color.canvas')).stroke($r('app.color.accent_muted')).strokeWidth(1)
        .position({ x: this.atlasSize * 0.02 - 3, y: this.atlasSize / 2 - 4 })
      Circle().width(6).height(6).fill($r('app.color.accent_muted')).stroke($r('app.color.accent_muted')).strokeWidth(1)
        .position({ x: this.atlasSize * 0.02 + 1 + (this.atlasSize * 0.96 - 2) * 0.84,
          y: this.atlasSize * 0.02 + 1 + (this.atlasSize * 0.96 - 2) * 0.13 })
      Circle().width(12).height(12).fill($r('app.color.canvas')).stroke($r('app.color.accent_muted')).strokeWidth(1)
        .position({ x: this.atlasSize / 2, y: this.atlasSize * 0.98 - 1 })
    }.width(this.atlasSize).height(this.atlasSize).opacity(0.5).clip(false)
  }

  @Builder
  middleOrbit() {
    Stack() {
      Circle().width(this.atlasSize * 0.68).height(this.atlasSize * 0.68).fill(Color.Transparent)
        .stroke($r('app.color.accent_muted')).strokeWidth(1)
      Circle().width(this.atlasSize * 0.68 + 10).height(this.atlasSize * 0.68 + 10).fill(Color.Transparent)
        .stroke($r('app.color.accent_muted')).strokeWidth(1)
      Circle().width(8).height(8).fill($r('app.color.canvas')).stroke($r('app.color.accent_muted')).strokeWidth(1)
        .position({ x: this.atlasSize * 0.16 - 3, y: this.atlasSize / 2 - 4 })
      Circle().width(6).height(6).fill($r('app.color.accent_muted')).stroke($r('app.color.accent_muted')).strokeWidth(1)
        .position({ x: this.atlasSize * 0.16 + 1 + (this.atlasSize * 0.68 - 2) * 0.84,
          y: this.atlasSize * 0.16 + 1 + (this.atlasSize * 0.68 - 2) * 0.13 })
    }.width(this.atlasSize).height(this.atlasSize).opacity(0.7).clip(false)
  }

  @Builder
  innerOrbit() {
    Stack() {
      Circle().width(this.atlasSize * 0.38).height(this.atlasSize * 0.38).fill(Color.Transparent)
        .stroke($r('app.color.accent_muted')).strokeWidth(1).strokeDashArray([2, 3])
      Circle().width(8).height(8).fill($r('app.color.canvas')).stroke($r('app.color.accent_muted')).strokeWidth(1)
        .position({ x: this.atlasSize * 0.31 - 3, y: this.atlasSize / 2 - 4 })
    }.width(this.atlasSize).height(this.atlasSize).opacity(0.6).clip(false)
  }

  build() {
    Stack() {
      this.outerOrbit()
      this.middleOrbit()
      this.innerOrbit()
      Rect().width(this.atlasSize * 0.8).height(this.atlasSize * 0.8).fill(Color.Transparent)
        .stroke($r('app.color.accent_muted')).strokeWidth(1).rotate({ angle: 45 }).opacity(0.15)
      Line().startPoint([0, 0]).endPoint([this.atlasSize * 1.04, 0]).width(this.atlasSize * 1.04).height(1)
        .stroke($r('app.color.accent_muted')).strokeWidth(1).rotate({ angle: 45 }).opacity(0.15)
      Line().startPoint([0, 0]).endPoint([this.atlasSize * 1.04, 0]).width(this.atlasSize * 1.04).height(1)
        .stroke($r('app.color.accent_muted')).strokeWidth(1).rotate({ angle: -45 }).opacity(0.15)
      Image($r('app.media.icon_star_four')).width(this.atlasSize * 0.24).height(this.atlasSize * 0.24)
        .fillColor($r('app.color.accent_muted')).objectFit(ImageFit.Contain)
      Text('N').fontFamily('StarwardSerif').fontSize(10).fontColor($r('app.color.accent_muted'))
        .position({ x: this.atlasSize * 0.49, y: this.atlasSize * 0.07 })
      Text('S').fontFamily('StarwardSerif').fontSize(10).fontColor($r('app.color.accent_muted'))
        .position({ x: this.atlasSize * 0.49, y: this.atlasSize * 0.89 })
    }.width(this.atlasSize).height(this.atlasSize).offset({ x: this.renderX, y: this.renderY }).clip(false)
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no-hide-descendants')
  }
}
