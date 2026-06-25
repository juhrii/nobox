import 'dart:convert';
import 'package:flutter/foundation.dart';

class ChatModel {
  final String id;
  final String contactId; // CtId — used by Inbox/Send and Inbox/Get
  final String sender;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  final bool isFavorite;
  final bool isGroup;
  final bool isBlocked;
  final String status; // "Resolved", "Assigned", "Unassigned"
  final String agentName;
  final List<String> tags;
  final String? avatarUrl;
  final String? lastMessageType; // "Sticker", "Unsupported Message", etc.
  final bool needReply;
  final bool muteAiAgent;
  final String funnel;
  final String notes;
  final String channelName;
  final String channelType;
  final String chId;
  final String accountId;
  final String ctRealId;
  final bool isLastMessageFromMe;
  final String link;
  final String campaign;
  final String deal;
  final String groupName;

  ChatModel({
    required this.id,
    this.contactId = '',
    required this.sender,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isArchived = false,
    this.isFavorite = false,
    this.isGroup = false,
    this.isBlocked = false,
    this.status = 'Unassigned',
    this.agentName = '',
    this.tags = const [],
    this.avatarUrl,
    this.lastMessageType,
    this.needReply = false,
    this.muteAiAgent = false,
    this.funnel = '',
    this.notes = '',
    this.channelName = '',
    this.channelType = '',
    this.chId = '',
    this.accountId = '',
    this.ctRealId = '',
    this.isLastMessageFromMe = false,
    this.link = '',
    this.campaign = '',
    this.deal = '',
    this.groupName = '',
  });

  ChatModel copyWith({
    String? id,
    String? contactId,
    String? sender,
    String? lastMessage,
    String? time,
    int? unreadCount,
    bool? isPinned,
    bool? isArchived,
    bool? isFavorite,
    bool? isGroup,
    bool? isBlocked,
    String? status,
    String? agentName,
    List<String>? tags,
    String? avatarUrl,
    String? lastMessageType,
    bool? needReply,
    bool? muteAiAgent,
    String? funnel,
    String? notes,
    String? channelName,
    String? channelType,
    String? chId,
    String? accountId,
    String? ctRealId,
    bool? isLastMessageFromMe,
    String? link,
    String? campaign,
    String? deal,
    String? groupName,
  }) {
    return ChatModel(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      sender: sender ?? this.sender,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isFavorite: isFavorite ?? this.isFavorite,
      isGroup: isGroup ?? this.isGroup,
      isBlocked: isBlocked ?? this.isBlocked,
      status: status ?? this.status,
      agentName: agentName ?? this.agentName,
      tags: tags ?? this.tags,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      needReply: needReply ?? this.needReply,
      muteAiAgent: muteAiAgent ?? this.muteAiAgent,
      funnel: funnel ?? this.funnel,
      notes: notes ?? this.notes,
      channelName: channelName ?? this.channelName,
      channelType: channelType ?? this.channelType,
      chId: chId ?? this.chId,
      accountId: accountId ?? this.accountId,
      ctRealId: ctRealId ?? this.ctRealId,
      isLastMessageFromMe: isLastMessageFromMe ?? this.isLastMessageFromMe,
      link: link ?? this.link,
      campaign: campaign ?? this.campaign,
      deal: deal ?? this.deal,
      groupName: groupName ?? this.groupName,
    );
  }
}

enum MessageStatus { sent, delivered, read }
enum MessageType { text, voice, image, video, document, sticker }

class Message {
  final String id;
  final String content;
  final bool isMe;
  final String time;
  final MessageStatus status;
  final Message? repliedMessage;
  final bool isSystemMessage;
  final MessageType messageType;
  final String? audioPath;
  final int audioDuration; // in seconds
  final String? imagePath;  // local file path
  final String? imageUrl;   // remote URL from server
  final String? videoUrl;   // remote video URL from server
  final String? documentName; // original filename for document messages
  final String? documentUrl;  // remote URL for document download
  final int ack; // 1: pending, 2: sent, 3: delivered, 4: failed, 5: read

  Message({
    this.id = '',
    required this.content,
    required this.isMe,
    required this.time,
    this.status = MessageStatus.sent,
    this.repliedMessage,
    this.isSystemMessage = false,
    this.messageType = MessageType.text,
    this.audioPath,
    this.audioDuration = 0,
    this.imagePath,
    this.imageUrl,
    this.videoUrl,
    this.documentName,
    this.documentUrl,
    this.ack = 0,
  });

  /// Format ISO timestamp "2026-03-25T05:42:28.107" → "25 Mar, 05:42"
  static String _formatIsoTime(String raw) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    try {
      String timeString = raw;
      // Jika dari server tidak ada penanda zona waktu (Z atau +), paksa anggap sebagai UTC ('Z')
      if (!timeString.endsWith('Z') && !timeString.contains('+') && timeString.length >= 19) {
        timeString += 'Z';
      }
      final dt = DateTime.parse(timeString).toLocal();
      return "${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return raw; // Return as-is if parsing fails
    }
  }

  /// Check if a filename looks like an image
  static bool _isImageFile(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext);
  }

  factory Message.fromJson(Map<String, dynamic> json, String currentUserEmail, {String? tenantId}) {
    final id = json['Id']?.toString() ?? '';
    // ChatMessages/List uses Type: 6 for system messages, Type: 1/2 for regular messages
    final typeVal = json['Type']?.toString();
    final isSystem = json['IsSystemMessage'] == true || 
                     typeVal?.toLowerCase() == 'system' ||
                     typeVal == '6';

    // Determine message content — ChatMessages/List uses 'Msg' field
    // Handle both String and Map for 'Msg'
    String content = '';
    final rawMsg = json['Msg'];
    if (rawMsg is String) {
      content = rawMsg;
    } else if (rawMsg is Map) {
      content = rawMsg['msg']?.toString() ?? rawMsg.toString();
    } else {
      content = json['Body']?.toString() ?? json['Message']?.toString() ?? json['message']?.toString() ?? json['Content']?.toString() ?? '';
    }
    
    // System messages (Type: 6) have JSON in Msg like {"msg":"Site.Inbox.UnmuteBotByAgent",...}
    // Parse it to show a readable label
    if (isSystem && content.startsWith('{')) {
      try {
        final parsed = Map<String, dynamic>.from(
          content is Map ? content : (json['Msg'] is Map ? json['Msg'] : {}),
        );
        final msgKey = parsed['msg']?.toString() ?? '';
        // Convert "Site.Inbox.UnmuteBotByAgent" → "Bot diaktifkan"
        if (msgKey.contains('UnmuteBot')) {
          content = '🤖 Bot diaktifkan';
        } else if (msgKey.contains('MuteBot')) {
          content = '🤖 Bot dinonaktifkan';
        } else if (msgKey.contains('Assign')) {
          content = '👤 Percakapan di-assign';
        } else if (msgKey.contains('Resolve')) {
          content = '✅ Percakapan diselesaikan';
        } else {
          content = '📋 $msgKey';
        }
      } catch (_) {
        // Keep original content if parsing fails
      }
    }

    // Determine if message is from "me" (the agent/user)
    // ChatMessages/List: if AgentId is set, it's an agent message (isMe = true)
    // Also check the older field names for backward compatibility
    bool isMe = false;
    if (!isSystem) {
      if (json['AgentId'] != null) {
        // AgentId is present → message was sent by an agent (us)
        isMe = true;
      } else if (json['IsMe'] == true) {
        isMe = true;
      } else {
        // Fallback: check email match
        final senderId = json['SenderId']?.toString() ?? json['FromId']?.toString() ?? json['sender_email'] ?? '';
        isMe = senderId == currentUserEmail;
      }
    }

    // Parse media files — check Files array first (any Type), then File field, then fallback by Type
    MessageType msgType = MessageType.text;
    String? imgUrl;
    String? audioPath;
    String? videoUrl;
    
    // Helper to check if a filename is a video
    bool isVideoFile(String fileName) {
      final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      return ['mp4', 'avi', 'mov', 'mkv', '3gp', 'webm', 'ogg_video'].contains(ext);
    }
    
    // Helper to check if a filename is an audio file
    bool isAudioFile(String fileName) {
      final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      return ['mp3', 'wav', 'ogg', 'opus', 'm4a', 'aac', 'weba', 'amr'].contains(ext);
    }

    // Debug: log raw JSON for media-related messages
    if (typeVal == '2' || typeVal == '16' || typeVal == '3' || typeVal == '4' ||
        json['Files'] != null || json['File'] != null) {
      assert(() {
        debugPrint('Message.fromJson MEDIA: Type=$typeVal, Files=${json['Files']}, File=${json['File']}, Id=${json['Id']}, IdAlias=${json['IdAlias']}, tenantId=$tenantId, Msg=${json['Msg']}');
        return true;
      }());
    }

    // Helper to extract file path from Files array or File field
    String extractFilePath(dynamic fileData) {
      String filePath = fileData.toString();
      
      // Fix for backend serialization bug where it sends the class name instead of a file
      if (filePath.contains('NoboxWhatsapp') || filePath.contains('MessageResponse')) {
        return '';
      }

      if (fileData is Map) {
        if (fileData['Filename'] != null) filePath = fileData['Filename'].toString();
        else if (fileData['url'] != null) filePath = fileData['url'].toString();
      } else if (filePath.startsWith('{')) {
        try {
          final fileMap = jsonDecode(filePath);
          if (fileMap['Filename'] != null) filePath = fileMap['Filename'].toString();
          else if (fileMap['url'] != null) filePath = fileMap['url'].toString();
        } catch (_) {}
      }
      
      // Clean up MIME types or query params (e.g., .ogg; codecs=opus)
      if (filePath.contains(';')) {
        filePath = filePath.split(';').first;
      }
      if (filePath.contains('?')) {
        filePath = filePath.split('?').first;
      }
      return filePath.trim();
    }

    // Helper to extract OriginalName from file data (for type detection fallback)
    String extractOriginalName(dynamic fileData) {
      if (fileData is Map) {
        return fileData['OriginalName']?.toString() ?? '';
      } else if (fileData is String && fileData.startsWith('{')) {
        try {
          final fileMap = jsonDecode(fileData);
          return fileMap['OriginalName']?.toString() ?? '';
        } catch (_) {}
      }
      return '';
    }

    String? docName;
    String? docUrl;

    if (json['Files'] != null && json['Files'] is List && (json['Files'] as List).isNotEmpty) {
      final firstFile = (json['Files'] as List).first;
      final filePath = extractFilePath(firstFile);
      final originalName = extractOriginalName(firstFile);
      // Sticker detection FIRST (typeVal == '16') — before extension checks
      if (typeVal == '16' && filePath.isNotEmpty) {
        msgType = MessageType.sticker;
        imgUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
        content = '🌟 Sticker';
      } else if (isAudioFile(filePath) || isAudioFile(originalName)) {
        msgType = MessageType.voice;
        audioPath = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
      } else if (isVideoFile(filePath) || isVideoFile(originalName)) {
        msgType = MessageType.video;
        videoUrl = filePath.startsWith('http') 
            ? filePath 
            : 'https://id.nobox.ai/upload/$filePath';
        content = '📹 Video';
      } else if (_isImageFile(filePath) || _isImageFile(originalName)) {
        msgType = MessageType.image;
        imgUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
      } else if (typeVal == '2') {
        // Fallback by API Type when extension is unrecognized
        msgType = MessageType.voice;
        audioPath = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
      } else if (typeVal == '4') {
        msgType = MessageType.video;
        videoUrl = filePath.startsWith('http') 
            ? filePath 
            : 'https://id.nobox.ai/upload/$filePath';
        content = '📹 Video';
      } else if (typeVal == '3') {
        msgType = MessageType.image;
        imgUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
      } else if (filePath.isNotEmpty) {
        // Unrecognized file type → treat as document
        msgType = MessageType.document;
        docName = originalName.isNotEmpty ? originalName : filePath.split('/').last;
        docUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
        content = '📄 $docName';
      }
    } else if (json['File'] != null && json['File'].toString().isNotEmpty) {
      final filePath = extractFilePath(json['File']);
      final originalName = extractOriginalName(json['File']);
      // Sticker detection FIRST (typeVal == '16') — before extension checks
      if (typeVal == '16' && filePath.isNotEmpty) {
        msgType = MessageType.sticker;
        imgUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
        content = '🌟 Sticker';
      } else if (isAudioFile(filePath) || isAudioFile(originalName)) {
        msgType = MessageType.voice;
        audioPath = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
      } else if (isVideoFile(filePath) || isVideoFile(originalName)) {
        msgType = MessageType.video;
        videoUrl = filePath.startsWith('http') 
            ? filePath 
            : 'https://id.nobox.ai/upload/$filePath';
        content = '📹 Video';
      } else if (_isImageFile(filePath) || _isImageFile(originalName)) {
        msgType = MessageType.image;
        imgUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
      } else if (typeVal == '2') {
        // Fallback by API Type when extension is unrecognized
        msgType = MessageType.voice;
        audioPath = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
      } else if (typeVal == '4') {
        msgType = MessageType.video;
        videoUrl = filePath.startsWith('http') 
            ? filePath 
            : 'https://id.nobox.ai/upload/$filePath';
        content = '📹 Video';
      } else if (typeVal == '3') {
        msgType = MessageType.image;
        imgUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
      } else if (filePath.isNotEmpty) {
        // Unrecognized file type → treat as document
        msgType = MessageType.document;
        docName = originalName.isNotEmpty ? originalName : filePath.split('/').last;
        docUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
        content = '📄 $docName';
      }
    } else if (typeVal == '16' || typeVal == '2' || typeVal == '3') {
      // No Files/File data available
      msgType = MessageType.text;
      content = '⚠️ Pesan ini tidak dapat ditampilkan. Buka WhatsApp di HP untuk melihat pesan ini.';
    }

    // Fallback: if this is an image message but content is empty, set readable label
    if (msgType == MessageType.image && content.trim().isEmpty) {
      content = '📷 Photo';
    }

    // Format time — parse ISO timestamp to readable format
    final rawTime = json['In']?.toString() ?? json['timestamp']?.toString() ?? json['CreatedAt']?.toString() ?? '';
    final formattedTime = rawTime.contains('T') ? _formatIsoTime(rawTime) : rawTime;

    // Debug: log audio path for voice messages
    if (msgType == MessageType.voice) {
      debugPrint('🔊 Message.fromJson VOICE: id=$id, audioPath=$audioPath, Files=${json['Files']}, File=${json['File']}, Type=$typeVal');
    }

    int parsedAck = 2; // Default to sent if not present
    final ackVal = json['Ack'] ?? json['ack'] ?? json['ack_status'];
    if (ackVal != null) {
      if (ackVal is int) parsedAck = ackVal;
      else if (ackVal is String) parsedAck = int.tryParse(ackVal) ?? 2;
    } else {
      parsedAck = isSystem ? 0 : 2;
    }

    return Message(
      id: id,
      content: content,
      isMe: isMe,
      time: formattedTime,
      status: MessageStatus.read,
      isSystemMessage: isSystem,
      messageType: msgType,
      imageUrl: imgUrl,
      audioPath: audioPath,
      videoUrl: videoUrl,
      documentName: docName,
      documentUrl: docUrl,
      ack: parsedAck,
    );
  }

  Message copyWith({
    String? id,
    String? content,
    bool? isMe,
    String? time,
    MessageStatus? status,
    Message? repliedMessage,
    bool? isSystemMessage,
    MessageType? messageType,
    String? audioPath,
    int? audioDuration,
    String? imagePath,
    String? imageUrl,
    String? videoUrl,
    String? documentName,
    String? documentUrl,
    int? ack,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      isMe: isMe ?? this.isMe,
      time: time ?? this.time,
      status: status ?? this.status,
      repliedMessage: repliedMessage ?? this.repliedMessage,
      isSystemMessage: isSystemMessage ?? this.isSystemMessage,
      messageType: messageType ?? this.messageType,
      audioPath: audioPath ?? this.audioPath,
      audioDuration: audioDuration ?? this.audioDuration,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      documentName: documentName ?? this.documentName,
      documentUrl: documentUrl ?? this.documentUrl,
      ack: ack ?? this.ack,
    );
  }
}
