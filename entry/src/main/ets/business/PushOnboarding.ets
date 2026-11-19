/** A local presentation receipt, never a substitute for server-side consent. */
export interface PushOnboardingStore {
  wasPrompted(owner: string): boolean;
  /** Must durably claim before returning true. Existing or unavailable claims must not show a prompt. */
  claim(owner: string): boolean;
}

export type PushOnboardingPhase = 'hidden' | 'subscription' | 'notifications';
