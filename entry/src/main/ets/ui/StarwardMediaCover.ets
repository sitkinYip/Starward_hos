/** Shared native media presentation. The caller owns the captured media session and its callbacks. */
export function starwardMediaCoverOptions(reducedMotion: boolean,
  onWillDismiss: (action: DismissContentCoverAction) => void, onDisappear: () => void,
  transition?: TransitionEffect): ContentCoverOptions {
  return {
    backgroundColor: $r('app.color.media_viewer_background'),
    enableSafeArea: false,
    modalTransition: reducedMotion ? ModalTransition.NONE : ModalTransition.ALPHA,
    transition,
    onWillDismiss,
    onDisappear
  };
}
