import { AssignmentSummary } from './models';

export function assignmentKind(item: AssignmentSummary, rank: number, now: number): string {
  if (item.status === 'completed') {
    return 'completed';
  }
  if (item.status === 'cancelled') {
    return 'cancelled';
  }
  if (item.endsAt.length > 0 && Date.parse(item.endsAt) <= now) {
    return 'expired';
  }
  if (item.startsAt.length > 0 && Date.parse(item.startsAt) > now) {
    return 'waiting';
  }
  if (item.status === 'assigned' &&
    (rank < item.minLevel || (item.maxLevel !== null && rank > item.maxLevel))) {
    return 'locked';
  }
  return item.status === 'active' ? 'active' : 'ready';
}

export function assignmentState(item: AssignmentSummary, rank: number, now: number): string {
  const kind: string = assignmentKind(item, rank, now);
  switch (kind) {
    case 'completed': return '故事已解开';
    case 'cancelled': return '旅程已撤回';
    case 'expired': return '已过开放时间';
    case 'waiting': return '静候启程';
    case 'locked': return '等级暂不符合';
    case 'active': return '探索进行中';
    default: return '可以出发';
  }
}
