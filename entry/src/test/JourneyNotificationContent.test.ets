import { describe, expect, it } from '@ohos/hypium';
import { LegacyRichBlock, legacyImageSources, legacyRichBlocks } from '../main/ets/business/LegacyRichContent';
import { JourneyNotificationBlock, journeyNotificationBlocks,
  journeyNotificationHasLink, journeyNotificationHasMedia,
  journeyNotificationPreview } from '../main/ets/business/JourneyNotificationContent';

export default function journeyNotificationContentTests(): void {
  describe('JourneyNotificationContent', () => {
    it('groups images from one quest body in authored order and retains repeated image locations', 0, () => {
      const blocks: LegacyRichBlock[] = legacyRichBlocks('题面\r\n\n[[重点]]((护照||/profile))' +
        '{{/图一.png}}<<https://media.example/show.mp4||javascript:alert(1)>>{{/图二.png}}{{/图一.png}}');
      expect(blocks[0].spans[0].text).assertEqual('题面\n\n');
      expect(blocks[0].spans[2].linkTarget).assertEqual('/profile');
      expect(blocks[2].kind).assertEqual('video');
      expect(blocks[2].poster).assertEqual('');
      expect(legacyImageSources(blocks)).assertDeepEquals(['/图一.png', '/图二.png', '/图一.png']);
    });

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

    it('only authorizes exact attachments and links from the current letter revision', 0, () => {
      const first: JourneyNotificationBlock[] = journeyNotificationBlocks(
        '{{/one.png}}<<https://media.example/video.mp4||/first-poster.png>>((阅读||/profile))');
      const revised: JourneyNotificationBlock[] = journeyNotificationBlocks(
        '{{/two.png}}<<https://media.example/video.mp4||/second-poster.png>>((阅读||/rewards))');
      expect(journeyNotificationHasMedia(first, 'image', '/one.png')).assertTrue();
      expect(journeyNotificationHasMedia(revised, 'image', '/one.png')).assertFalse();
      expect(journeyNotificationHasMedia(revised, 'image', '/second-poster.png')).assertFalse();
      expect(journeyNotificationHasMedia(revised, 'video', 'https://media.example/video.mp4',
        '/second-poster.png')).assertTrue();
      expect(journeyNotificationHasMedia(revised, 'video', 'https://media.example/video.mp4',
        '/first-poster.png')).assertFalse();
      expect(journeyNotificationHasLink(first, '/profile')).assertTrue();
      expect(journeyNotificationHasLink(revised, '/profile')).assertFalse();
    });
  });
}
