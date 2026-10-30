// Deliberate first-slice projection of backend/contracts/game.ts.
// Media, clues, questions and rank visualConfig are outside this read-only slice.
export class Rank {
  id: string = '';
  order: number = 0;
  name: string = '';
  minTotalXp: number = 0;
}

export class ExtraDisplay {
  key: string = '';
  label: string = '';
  text: string = '';
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
  extraDisplay: ExtraDisplay[] = [];
}

// Platform-independent image payloads. Protected URLs and credentials stay in the Repository.
export class AvatarUpload {
  filename: string = 'avatar.jpg';
  mimeType: string = 'image/jpeg';
  data: ArrayBuffer = new ArrayBuffer(0);
}

export class AvatarImage {
  data: ArrayBuffer = new ArrayBuffer(0);
  mimeType: string = '';
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

export function validateDisplayName(value: string): string {
  if (value.trim().length === 0) {
    return '给自己起个名字，再出发吧。';
  }
  return value.trim().length > 40 ? '昵称格式不正确' : '';
}

export function avatarMimeType(data: ArrayBuffer): string {
  const bytes: Uint8Array = new Uint8Array(data);
  if (bytes.length >= 3 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 && bytes[0] === 137 && bytes[1] === 80 && bytes[2] === 78 && bytes[3] === 71 &&
    bytes[4] === 13 && bytes[5] === 10 && bytes[6] === 26 && bytes[7] === 10) {
    return 'image/png';
  }
  if (bytes.length >= 12 && bytes[0] === 82 && bytes[1] === 73 && bytes[2] === 70 && bytes[3] === 70 &&
    bytes[8] === 87 && bytes[9] === 69 && bytes[10] === 66 && bytes[11] === 80) {
    return 'image/webp';
  }
  return '';
}

export function validateAvatarUpload(value: AvatarUpload): string {
  if (value.data.byteLength === 0 || value.data.byteLength > 2 * 1024 * 1024) {
    return '资料无效：头像仅支持 JPG、PNG、WebP，最大 2MB';
  }
  const detectedMime: string = avatarMimeType(value.data);
  if (value.filename.length === 0 || /[\/\\\r\n]/.test(value.filename) ||
    detectedMime.length === 0 || detectedMime !== value.mimeType) {
    return '请选择 JPG、PNG 或 WebP 图片。';
  }
  return '';
}
