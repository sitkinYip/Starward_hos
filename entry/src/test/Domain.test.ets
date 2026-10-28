import { describe, expect, it } from '@ohos/hypium';
import { assignmentKind, assignmentState } from '../main/ets/business/assignmentState';
import { AssignmentSummary, utf8Length, validatePasswordChange } from '../main/ets/business/models';

export default function domainTests(): void {
  describe('Domain', () => {
    it('passwordValidationHonorsUtf8Limit', 0, () => {
      const multibyte: string = '星'.repeat(25);
      expect(multibyte.length).assertEqual(25);
      expect(utf8Length(multibyte)).assertEqual(75);
      expect(validatePasswordChange('Starward1234', multibyte, multibyte).length > 0).assertTrue();
      expect(utf8Length('星辰🚀')).assertEqual(10);
      expect(validatePasswordChange('Starward1234', 'NewStarward1234', 'NewStarward1234')).assertEqual('');
    });

    it('passwordValidationRejectsMismatchOldAndBounds', 0, () => {
      expect(validatePasswordChange('', 'NewStarward1234', 'NewStarward1234').length > 0).assertTrue();
      expect(validatePasswordChange('Starward1234', 'short', 'short').length > 0).assertTrue();
      expect(validatePasswordChange('Starward1234', 'a'.repeat(72), 'a'.repeat(72)).length > 0).assertTrue();
      expect(validatePasswordChange('Starward1234', 'NewStarward1234', 'Different1234').length > 0).assertTrue();
      expect(validatePasswordChange('Starward1234', 'Starward1234', 'Starward1234').length > 0).assertTrue();
    });

    it('completedAndCancelledPrecedeTimeWindows', 0, () => {
      const item: AssignmentSummary = new AssignmentSummary();
      item.startsAt = '2026-11-01T00:00:00Z';
      item.endsAt = '2026-10-01T00:00:00Z';
      item.minLevel = 5;
      item.status = 'completed';
      expect(assignmentKind(item, 1, Date.parse('2026-10-27T00:00:00Z'))).assertEqual('completed');
      expect(assignmentState(item, 1, Date.parse('2026-10-27T00:00:00Z'))).assertEqual('故事已解开');
      item.status = 'cancelled';
      expect(assignmentKind(item, 1, Date.parse('2026-10-27T00:00:00Z'))).assertEqual('cancelled');
    });

    it('timeAndRankBoundariesRemainExclusiveAtEnd', 0, () => {
      const item: AssignmentSummary = new AssignmentSummary();
      const now: number = Date.parse('2026-10-27T00:00:00Z');
      item.startsAt = '2026-10-27T00:00:00Z';
      item.endsAt = '2026-10-28T00:00:00Z';
      item.minLevel = 2;
      item.maxLevel = 4;
      expect(assignmentKind(item, 1, now)).assertEqual('locked');
      expect(assignmentKind(item, 2, now)).assertEqual('ready');
      expect(assignmentKind(item, 4, now)).assertEqual('ready');
      expect(assignmentKind(item, 5, now)).assertEqual('locked');
      expect(assignmentKind(item, 3, Date.parse(item.endsAt))).assertEqual('expired');
      expect(assignmentKind(item, 3, now - 1)).assertEqual('waiting');
    });

    it('activeAssignmentKeepsAccessAfterRankChanges', 0, () => {
      const item: AssignmentSummary = new AssignmentSummary();
      item.status = 'active';
      item.minLevel = 2;
      item.maxLevel = 4;
      expect(assignmentKind(item, 9, Date.now())).assertEqual('active');
    });
  });
}
