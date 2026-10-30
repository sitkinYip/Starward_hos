import { describe, expect, it } from '@ohos/hypium';
import { GameFailure } from '../main/ets/business/models';
import { decodeApiFailure, decodeAssignment, decodeAssignments, decodeFileToken, decodeLogin, decodePassword, decodePlayer } from '../main/ets/data/DtoDecoder';
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

function playerWithDisplay(display: string): string {
  return PLAYER_JSON.slice(0, -1) + ',"extraDisplay":' + display + '}';
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

    it('fileTokenRequiresANonemptyString', 0, () => {
      expect(decodeFileToken('{"token":"temporary-file-token"}')).assertEqual('temporary-file-token');
      expectContractFailure(() => { decodeFileToken('{"token":""}'); });
      expectContractFailure(() => { decodeFileToken('{"token":null}'); });
      expectContractFailure(() => { decodeFileToken('{"token":5}'); });
      expectContractFailure(() => { decodeFileToken('{}'); });
    });

    it('defaultsAbsentAndNonArrayOptionalDisplayToEmptyWithoutWeakeningCorePlayer', 0, () => {
      expect(decodePlayer(PLAYER_JSON).extraDisplay.length).assertEqual(0);
      const values: string[] = ['null', '{}', '"legacy"', '2', 'true', '[]'];
      for (let i: number = 0; i < values.length; i++) {
        expect(decodePlayer(playerWithDisplay(values[i])).extraDisplay.length).assertEqual(0);
      }
      expectContractFailure(() => {
        decodePlayer(playerWithDisplay('null').replace('"totalXp":0', '"totalXp":"invalid"'));
      });
    });

    it('preservesServerDisplayFieldsOnMeProfileAndPasswordPlayerDecoding', 0, () => {
      const body: string = playerWithDisplay('[{"key":"team","label":"所属队伍","text":"追星组\\n第二行","ignored":"extension"},' +
        '{"key":"","label":"","text":""}]');
      const player = decodePlayer(body);
      expect(player.extraDisplay.length).assertEqual(2);
      expect(player.extraDisplay[0].key).assertEqual('team');
      expect(player.extraDisplay[0].label).assertEqual('所属队伍');
      expect(player.extraDisplay[0].text).assertEqual('追星组\n第二行');
      expect(player.extraDisplay[1].key).assertEqual('');
      expect(player.extraDisplay[1].label).assertEqual('');
      expect(player.extraDisplay[1].text).assertEqual('');
      const rotated = decodePassword('{"token":"rotated-test-token","player":' + body + '}');
      expect(rotated.player.extraDisplay.length).assertEqual(2);
      expect(rotated.player.extraDisplay[0].text).assertEqual(player.extraDisplay[0].text);
    });

    it('isolatesMalformedOptionalDisplayItemsAndEnforcesTheFormalWebStringLimits', 0, () => {
      const display: string = '[null,[],1,true,"old",{},' +
        '{"key":1,"label":"队伍","text":"甲"},' +
        '{"key":"a","label":false,"text":"甲"},' +
        '{"key":"b","label":"队伍","text":null},' +
        '{"key":"c","label":"队伍"},' +
        '{"key":"' + 'k'.repeat(61) + '","label":"队伍","text":"甲"},' +
        '{"key":"d","label":"' + '字'.repeat(101) + '","text":"甲"},' +
        '{"key":"e","label":"队伍","text":"' + '字'.repeat(4001) + '"},' +
        '{"key":"' + 'k'.repeat(60) + '","label":"' + '字'.repeat(100) + '","text":"' + '字'.repeat(4000) + '"}]';
      const player = decodePlayer(playerWithDisplay(display));
      expect(player.extraDisplay.length).assertEqual(1);
      expect(player.extraDisplay[0].key.length).assertEqual(60);
      expect(player.extraDisplay[0].label.length).assertEqual(100);
      expect(player.extraDisplay[0].text.length).assertEqual(4000);
    });

    it('keepsTheFirstValidDisplayKeyAndItsServerOrder', 0, () => {
      const player = decodePlayer(playerWithDisplay('[{"key":"team","label":null,"text":"invalid"},' +
        '{"key":"team","label":"队伍","text":"first"},' +
        '{"key":"badge","label":"称号","text":"second"},' +
        '{"key":"team","label":"重复","text":"ignored"},' +
        '{"key":"Team","label":"大写","text":"third"}]'));
      expect(player.extraDisplay.length).assertEqual(3);
      expect(player.extraDisplay[0].key).assertEqual('team');
      expect(player.extraDisplay[0].text).assertEqual('first');
      expect(player.extraDisplay[1].key).assertEqual('badge');
      expect(player.extraDisplay[2].key).assertEqual('Team');
    });

    it('considersOnlyTheFirstHundredRawDisplayItems', 0, () => {
      let display: string = '[';
      for (let i: number = 0; i < 99; i++) {
        display += 'null,';
      }
      display += '{"key":"hundred","label":"第100项","text":"kept"},' +
        '{"key":"overflow","label":"第101项","text":"ignored"}]';
      const player = decodePlayer(playerWithDisplay(display));
      expect(player.extraDisplay.length).assertEqual(1);
      expect(player.extraDisplay[0].key).assertEqual('hundred');
    });
  });
}
