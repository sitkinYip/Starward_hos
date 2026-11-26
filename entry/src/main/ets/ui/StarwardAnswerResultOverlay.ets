import { StarwardGlassBackdrop } from './StarwardGlassBackdrop';
import { STARWARD_PAGE_TRANSITION_MS } from './StarwardMotion';

/** Shared full-window presentation for both answer outcomes. */
@ComponentV2
export struct StarwardAnswerResultOverlay {
  @Require @Param nodeId: string;
  @Require @Param backdropId: string;
  @Param reducedMotion: boolean = true;
  @Param dismissible: boolean = true;
  @BuilderParam content: () => void;
  @Event dismiss: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      StarwardGlassBackdrop({ nodeId: this.backdropId, dismissible: this.dismissible,
        dismiss: () => this.dismiss() })
      this.content()
    }.id(this.nodeId).width('100%').height('100%').hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
      .transition(TransitionEffect.OPACITY.animation({
        duration: this.reducedMotion ? 0 : STARWARD_PAGE_TRANSITION_MS, curve: Curve.EaseOut
      }))
  }
}
