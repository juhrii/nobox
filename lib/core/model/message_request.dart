// =====================================================================
// FITUR: Model Request Pesan (Message)
// FILE: lib/core/model/message_request.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Class model untuk membungkus data pengiriman pesan sebelum dikirim ke API
// =====================================================================
class MessageRequest {
  final String receiver;
  final String content;
  final String? accountId;
  final String? channelId;
  final String? contactId;
  final String? attachment;
  final String? extId;

  MessageRequest({
    required this.receiver,
    required this.content,
    this.accountId,
    this.channelId,
    this.contactId,
    this.attachment,
    this.extId,
  });

  // FITUR: Convert ke JSON
  // FUNGSI: Mengubah objek MessageRequest menjadi format JSON (Map) sesuai standar body request API
  Map<String, dynamic> toJson() {
    return {
      'To': receiver,
      'Message': content,
      if (accountId != null) 'AccountId': accountId,
      if (channelId != null) 'ChannelId': channelId,
      if (contactId != null) 'ContactId': contactId,
      if (attachment != null) 'Attachment': attachment,
      if (extId != null) 'ExtId': extId,
    };
  }
}
