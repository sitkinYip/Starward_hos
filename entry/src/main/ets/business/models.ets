// Deliberate first-slice projection of backend/contracts/game.ts.
// Media, clues, questions and rank visualConfig are outside this read-only slice.
export class Rank {
  id: string = '';
  order: number = 0;
  name: string = '';
  minTotalXp: number = 0;
}

export class Player {
  id: string = '';
  account: string = '';
  displayName: string = '';
  avatar: string = '';
  mustChangePassword: boolean = false;
  totalXp: number = 0;
  level: Rank = new Rank();
  nextLevel: Rank | null = null;
}

export class AssignmentSummary {
  id: string = '';
  player: string = '';
  session: string = '';
  status: string = 'assigned';
  order: number = 0;
  startsAt: string = '';
  endsAt: string = '';
  startedAt: string = '';
  completedAt: string = '';
  previousAssignment: string = '';
  title: string = '';
  description: string = '';
  minLevel: number = 0;
  maxLevel: number | null = null;
  completedLevels: number = 0;
  totalLevels: number = 0;
}

export class AssignmentDetail extends AssignmentSummary {
  currentIndex: number = 0;
  serverTime: string = '';
}

export class GameFailure extends Error {
  code: string;
  status: number;

  constructor(code: string, message: string, status: number = 0) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

export function utf8Length(value: string): number {
  let bytes: number = 0;
  for (let i: number = 0; i < value.length; i++) {
    const code: number = value.charCodeAt(i);
    if (code < 0x80) {
      bytes++;
    } else if (code < 0x800) {
      bytes += 2;
    } else if (code >= 0xd800 && code <= 0xdbff && i + 1 < value.length &&
      value.charCodeAt(i + 1) >= 0xdc00 && value.charCodeAt(i + 1) <= 0xdfff) {
      bytes += 4;
      i++;
    } else {
      bytes += 3;
    }
  }
  return bytes;
}

export function validatePasswordChange(oldPassword: string, password: string, confirmation: string): string {
  if (oldPassword.length === 0) {
    return '请输入当前密码。';
  }
  if (password.length < 10 || password.length > 71 || utf8Length(password) > 72) {
    return '新密码须为 10—71 个字符，且 UTF-8 编码不超过 72 字节。';
  }
  if (password !== confirmation) {
    return '两次新密码不一致，请再核对一下。';
  }
  if (password === oldPassword) {
    return '新密码不能与当前密码相同。';
  }
  return '';
}
