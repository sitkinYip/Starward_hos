export class GameNotification {
  readonly id: string;
  readonly title: string;
  readonly content: string;
  readonly popupTitle: string;
  readonly buttonText: string;
  readonly sentAt: string;
  readonly readAt: string;
  readonly assignmentId: string;

  constructor(id: string, title: string, content: string, popupTitle: string, buttonText: string,
    sentAt: string, readAt: string, assignmentId: string) {
    this.id = id;
    this.title = title;
    this.content = content;
    this.popupTitle = popupTitle;
    this.buttonText = buttonText;
    this.sentAt = sentAt;
    this.readAt = readAt;
    this.assignmentId = assignmentId;
  }

  withReadAt(readAt: string): GameNotification {
    return new GameNotification(this.id, this.title, this.content, this.popupTitle, this.buttonText,
      this.sentAt, readAt, this.assignmentId);
  }
}
