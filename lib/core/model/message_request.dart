class MessageRequest {
  final String receiver;
  final String content;
  final String? accountId;
  final String? channelId;
  final String? contactId;
  final String? attachment;

  MessageRequest({
    required this.receiver,
    required this.content,
    this.accountId,
    this.channelId,
    this.contactId,
    this.attachment,
  });

  Map<String, dynamic> toJson() {
    return {
      'To': receiver,
      'Message': content,
      if (accountId != null) 'AccountId': accountId,
      if (channelId != null) 'ChannelId': channelId,
      if (contactId != null) 'ContactId': contactId,
      if (attachment != null) 'Attachment': attachment,
    };
  }
}
