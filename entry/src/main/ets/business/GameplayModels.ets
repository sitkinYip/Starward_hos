import { AssignmentDetail, Player } from './models';

// Platform-independent gameplay projection of backend/contracts/game.ts.
// URLs and effects are data boundaries; decoding them does not implement media or clue playback.
export class GameplayContentBlock {
  text: string = '';
  hint: string = '';
  imageUrl: string = '';
  imageUrls: string[] = [];
  videoUrl: string = '';
}

export class GameplayOption {
  key: string = '';
  text: string = '';
  imageUrl: string = '';
  videoUrl: string = '';
}

export class GameplayQuestion {
  id: string = '';
  kind: string = '';
  title: string = '';
  placeholder: string = '';
  content: GameplayContentBlock[] = [];
  options: GameplayOption[] = [];
}

export class GameplayPresentation {
  backgroundMode: string | undefined = undefined;
  hideTitle: boolean | undefined = undefined;
  bgmMode: string | undefined = undefined;
  bgmUrl: string | undefined = undefined;
  backgroundUrl: string | undefined = undefined;
  completionStyle: string | undefined = undefined;
}

export class GameplayLevel {
  id: string = '';
  position: number = 0;
  xp: number = 0;
  autoNext: boolean = false;
  completedAt: string = '';
  wrongCount: number = 0;
  cooldownUntil: string = '';
  locked: boolean = false;
  presentationOverride: GameplayPresentation = new GameplayPresentation();
  question: GameplayQuestion | null = null;
  lastAnswer: string = '';
}

export class GameplayEffect {
  type: string = 'clue';
  clueId: string = '';
  autoPlay: boolean | undefined = undefined;
}

export class GameplayClueContent {
  title: string = '';
  text: string = '';
  url: string = '';
  imageUrls: string[] = [];
  buttonText: string = '';
  description: string | undefined = undefined;
  tips: string | undefined = undefined;
}

export class GameplayClue {
  trigger: string = '';
  id: string = '';
  source: string = 'session';
  definitionId: string = '';
  question: string = '';
  sessionLevel: string = '';
  kind: string = '';
  position: number = 0;
  narrative: string = '';
  autoPlay: boolean = false;
  content: GameplayClueContent = new GameplayClueContent();
  unlockedAt: string = '';
}

export class GameplayCompletionTarget {
  kind: string = '';
  id: string = '';
  url: string = '';
}

export class GameplaySnapshot {
  detail: AssignmentDetail = new AssignmentDetail();
  presentation: GameplayPresentation = new GameplayPresentation();
  completionTarget: GameplayCompletionTarget | null = null;
  levels: GameplayLevel[] = [];
  clues: GameplayClue[] = [];
  transitionEffects: GameplayEffect[] = [];
}

export class GameplayAnswerResult {
  result: string = '';
  xpDelta: number = 0;
  rewardIds: string[] = [];
  effects: GameplayEffect[] = [];
  assignment: GameplaySnapshot = new GameplaySnapshot();
  player: Player = new Player();
}
