import { describe, expect, it } from '@ohos/hypium';
import { JourneyNotificationBlock, journeyNotificationBlocks,
  journeyNotificationPreview } from '../main/ets/business/JourneyNotificationContent';

export default function journeyNotificationContentTests(): void {
  describe('JourneyNotificationContent', () => {
    it('retains rich spans and ordered media without exposing URLs in the row preview', 0, () => {
      const content: string = '信件\r\n[[关键]]((查看||/profile)){{/photo.png}}' +
        '<<https://media.example/reply.mp4||/cover.png>> 后续';
      const blocks: JourneyNotificationBlock[] = journeyNotificationBlocks(content);
      expect(blocks.length).assertEqual(4);
      expect(blocks[0].spans[0].text).assertEqual('信件\n');
      expect(blocks[0].spans[1].highlight).assertTrue();
      expect(blocks[0].spans[2].linkTarget).assertEqual('/profile');
      expect(blocks[1].kind).assertEqual('image');
      expect(blocks[1].url).assertEqual('/photo.png');
      expect(blocks[2].kind).assertEqual('video');
      expect(blocks[2].poster).assertEqual('/cover.png');
      expect(journeyNotificationPreview(content)).assertEqual('信件 关键查看 后续');
      expect(journeyNotificationPreview('{{/photo.png}}')).assertEqual('打开查看来信内容');
    });

    it('keeps unsafe link labels inert and drops invalid media destinations', 0, () => {
      const blocks: JourneyNotificationBlock[] = journeyNotificationBlocks(
        '((旧链接||javascript:alert(1)))((外站||//media.example))((带凭据||https://user@example.test/))' +
          '{{file://local/picture.png}}<<javascript:alert(1)>>');
      expect(blocks.length).assertEqual(1);
      expect(blocks[0].spans[0].text).assertEqual('旧链接');
      expect(blocks[0].spans[0].linkTarget).assertEqual('');
      expect(blocks[0].spans[1].linkTarget).assertEqual('');
      expect(blocks[0].spans[2].linkTarget).assertEqual('');
    });
  });
}
