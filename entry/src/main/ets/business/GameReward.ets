export type RewardStatus = 'available' | 'redeemed' | 'voided';
export type RewardClaimMethod = 'staff' | 'location' | 'locker';

export class GameRewardSnapshot {
  id: string = '';
  name: string = '';
  image: string = '';
  description: string = '';
  claimMethod: RewardClaimMethod = 'staff';
  publicInstructions: string = '';
}

export class GameReward {
  id: string = '';
  player: string = '';
  assignment: string = '';
  quantity: number = 0;
  status: RewardStatus = 'available';
  claimDetails: string = '';
  redeemedAt: string = '';
  created: string = '';
  snapshot: GameRewardSnapshot = new GameRewardSnapshot();

  sameDetails(other: GameReward): boolean {
    return this.id === other.id && this.player === other.player && this.status === other.status &&
      this.claimDetails === other.claimDetails && this.redeemedAt === other.redeemedAt &&
      this.snapshot.name === other.snapshot.name && this.snapshot.image === other.snapshot.image &&
      this.snapshot.description === other.snapshot.description &&
      this.snapshot.publicInstructions === other.snapshot.publicInstructions;
  }
}
