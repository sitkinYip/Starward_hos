import { describe, expect, it } from '@ohos/hypium';
import { GameFailure } from '../main/ets/business/models';
import { decodeApiFailure, decodeAssignment, decodeAssignments, decodeLogin, decodePassword, decodePlayer } from '../main/ets/data/DtoDecoder';
import { WEB_ASSIGNMENT_JSON, WEB_ASSIGNMENTS_JSON, WEB_PLAYER_JSON } from './fixtures/WebFixture';

export const PLAYER_JSON: string = '{"id":"playeralice","account":"alice","displayName":"Alice","avatar":"","mustChangePassword":true,"totalXp":0,"level":{"id":"rank1","order":1,"name":"初见者","minTotalXp":0},"nextLevel":null}';
export const ASSIGNMENT_JSON: string = '{"id":"assignment1","player":"playeralice","session":"session1","status":"assigned","order":1,"startsAt":"","endsAt":"","startedAt":"","completedAt":"","previousAssignment":"","title":"星辰探险","description":"测试场次","minLevel":1,"maxLevel":null,"completedLevels":0,"totalLevels":2,"currentIndex":0,"serverTime":"2026-10-27T00:00:00Z"}';

function expectContractFailure(action: () => void): void {
  let code: string = '';
  try {
    action();
  } catch (error) {
    code = (error as GameFailure).code;
  }
  expect(code).assertEqual('CONTRACT_ERROR');
}

export default function contractTests(): void {
  describe('Contract', () => {
    it('decodesFrozenWebPlayerFixtureWithoutReshaping', 0, () => {
      const player = decodePlayer(WEB_PLAYER_JSON);
      expect(player.id).assertEqual('playeralice');
      expect(player.displayName).assertEqual('远航者');
      expect(player.account).assertEqual('alice');
    });

    it('decodesFrozenWebAssignmentAndListFixturesWithoutReshaping', 0, () => {
      const detail = decodeAssignment(WEB_ASSIGNMENT_JSON);
      expect(detail.id).assertEqual('assignment1');
      expect(detail.title).assertEqual('星辰探险');
      expect(detail.totalLevels).assertEqual(2);
      const summaries = decodeAssignments(WEB_ASSIGNMENTS_JSON);
      expect(summaries.length).assertEqual(1);
      expect(summaries[0].title).assertEqual(detail.title);
      expect(summaries[0].totalLevels).assertEqual(detail.totalLevels);
    });

    it('decodesPocketBaseAuthAndPlayerBoundary', 0, () => {
      const auth = decodeLogin('{"token":"test-token","record":{"id":"playeralice"}}');
      expect(auth.playerId).assertEqual('playeralice');
      expect(auth.token).assertEqual('test-token');
      expect(decodePlayer(PLAYER_JSON).mustChangePassword).assertTrue();
      expect(decodePassword('{"token":"rotated-test-token","player":' + PLAYER_JSON + '}').player.id).assertEqual('playeralice');
    });

    it('decodesReadOnlyAssignmentProjection', 0, () => {
      const detail = decodeAssignment(ASSIGNMENT_JSON);
      expect(detail.id).assertEqual('assignment1');
      expect(detail.title).assertEqual('星辰探险');
      expect(detail.currentIndex).assertEqual(0);
      expect(decodeAssignments('{"items":[' + ASSIGNMENT_JSON + ']}').length).assertEqual(1);
      expect(decodeAssignments('{"items":[]}').length).assertEqual(0);
    });

    it('rejectsMalformedAndMissingAuthFields', 0, () => {
      expectContractFailure(() => { decodeLogin('<html>proxy</html>'); });
      expectContractFailure(() => { decodeLogin('{"token":"","record":{"id":"playeralice"}}'); });
      expectContractFailure(() => { decodeLogin('{"token":"token","record":null}'); });
      expectContractFailure(() => { decodePlayer(PLAYER_JSON.replace('"mustChangePassword":true', '"mustChangePassword":"false"')); });
      expectContractFailure(() => { decodePlayer(PLAYER_JSON.replace('"totalXp":0', '"totalXp":-1')); });
    });

    it('rejectsInvalidAssignmentDataRatherThanShowingEmptySuccess', 0, () => {
      expectContractFailure(() => { decodeAssignments('{"items":null}'); });
      expectContractFailure(() => { decodeAssignments('{"items":[null]}'); });
      expectContractFailure(() => { decodeAssignment(ASSIGNMENT_JSON.replace('"status":"assigned"', '"status":"unknown"')); });
      expectContractFailure(() => { decodeAssignment(ASSIGNMENT_JSON.replace('"serverTime":"2026-10-27T00:00:00Z"', '"serverTime":"nonsense"')); });
      expectContractFailure(() => { decodeAssignment(ASSIGNMENT_JSON.replace('"completedLevels":0', '"completedLevels":3')); });
    });

    it('usesStatusForProxyErrorsAndPreservesBusinessErrors', 0, () => {
      const unauthorized: GameFailure = decodeApiFailure('<html>error</html>', 401);
      expect(unauthorized.status).assertEqual(401);
      expect(unauthorized.code).assertEqual('UNAUTHORIZED');
      const blocked: GameFailure = decodeApiFailure('{"error":{"code":"MUST_CHANGE_PASSWORD","message":"请先修改密码"}}', 403);
      expect(blocked.code).assertEqual('MUST_CHANGE_PASSWORD');
      expect(blocked.message).assertEqual('请先修改密码');
    });
  });
}
