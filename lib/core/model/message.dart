import 'dart:convert';
import 'package:flutter/foundation.dart';

// =====================================================================
// FITUR: Model Obrolan Utama (ChatModel)
// FILE: lib/core/model/message.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Class utama UI untuk data chat/room yang ditampilkan di screen utama
// =====================================================================
class ChatModel {
  final String id;
  final String contactId; // CtId — digunakan oleh Inbox/Send dan Inbox/Get
  final String sender;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  final bool isFavorite;
  final bool isGroup;
  final bool isBlocked;
  final String status; // "Selesai", "Ditugaskan", "Belum Ditugaskan"
  final String agentName;
  final List<String> tags;
  final String? avatarUrl;
  final String? lastMessageType; // "Sticker", "Pesan Tidak Didukung", dll.
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
  final String groupId;

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
    this.groupId = '',
  });

  // FITUR: Copy With (ChatModel)
  // FUNGSI: Meng-copy objek ChatModel untuk mempermudah perubahan state di provider
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
    String? groupId,
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
      groupId: groupId ?? this.groupId,
    );
  }
}

enum MessageStatus { sent, delivered, read }
enum MessageType { text, voice, image, video, document, sticker }

// =====================================================================
// FITUR: Model Pesan (Message)
// FILE: lib/core/model/message.dart
// BARIS AWAL: 165 (setelah komentar ini)
// FUNGSI: Class utama untuk menampung satu gelembung pesan (teks, gambar, audio) di ruang chat
// =====================================================================
class Message {
  final String id;
  final String content;
  final bool isMe;
  final String time;
  final String rawTime; // RAW ISO string for accurate sorting
  final MessageStatus status;
  final Message? repliedMessage;
  final bool isSystemMessage;
  final MessageType messageType;
  final String? audioPath;
  final int audioDuration; // dalam detik
  final String? imagePath;  // path file lokal
  final String? imageUrl;   // URL remote dari server
  final String? videoUrl;   // URL video remote dari server
  final String? documentName; // nama file asli untuk pesan dokumen
  final String? documentUrl;  // URL remote untuk unduh dokumen
  final int ack; // 1: pending, 2: terkirim, 3: diterima, 4: gagal, 5: dibaca

  Message({
    this.id = '',
    required this.content,
    required this.isMe,
    required this.time,
    this.rawTime = '',
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
      return raw; // Kembalikan apa adanya jika proses parse gagal
    }
  }

  /// Cek apakah nama file terlihat seperti gambar
  static bool _isImageFile(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext);
  }

  // FITUR: Parse Pesan dari JSON
  // FUNGSI: Mengubah response JSON list messages API menjadi objek Message
  factory Message.fromJson(Map<String, dynamic> json, String currentUserEmail, {String? tenantId}) {
    String id = json['Id']?.toString() ?? '';
    if (id == '0' || id.isEmpty) {
      final idAlias = json['IdAlias']?.toString() ?? '';
      if (idAlias.isNotEmpty && idAlias != '0') {
        id = idAlias;
      } else {
        final timeStr = json['In']?.toString() ?? '';
        final contentStr = json['Msg']?.toString() ?? '';
        id = 'temp_${timeStr}_${contentStr.hashCode}';
      }
    }
    // ChatMessages/List menggunakan Type: 6 untuk pesan sistem, Type: 1/2 untuk pesan biasa
    final typeVal = json['Type']?.toString();
    final isSystem = json['IsSystemMessage'] == true || 
                     typeVal?.toLowerCase() == 'system' ||
                     typeVal == '6';

    // Tentukan konten pesan — ChatMessages/List menggunakan field 'Msg'
    // Tangani format String maupun Map untuk 'Msg'
    String content = '';
    final rawMsg = json['Msg'];
    if (rawMsg is String) {
      content = rawMsg;
    } else if (rawMsg is Map) {
      content = rawMsg['msg']?.toString() ?? rawMsg.toString();
    } else {
      content = json['Body']?.toString() ?? json['Message']?.toString() ?? json['message']?.toString() ?? json['Content']?.toString() ?? '';
    }
    
    // Tangani anomali dari API: 'document(Empty)' atau 'voice(Empty)'
    if (content.trim().toLowerCase() == 'document(empty)' || content.trim().toLowerCase() == 'voice(empty)') {
      content = '';
    }

    // Pesan sistem (Type: 6) memiliki JSON di Msg seperti {"msg":"Site.Inbox.UnmuteBotByAgent",...}
    // Parse untuk menampilkan label yang mudah dibaca
    if (isSystem && content.startsWith('{')) {
      try {
        final parsed = Map<String, dynamic>.from(
          content is Map ? content : (json['Msg'] is Map ? json['Msg'] : {}),
        );
        final msgKey = parsed['msg']?.toString() ?? '';
        // Ubah "Site.Inbox.UnmuteBotByAgent" → "Bot diaktifkan"
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
        // Pertahankan konten asli jika proses parse gagal
      }
    }

    // Tentukan apakah pesan berasal dari "saya" (agen/pengguna)
    // ChatMessages/List: jika AgentId ada, itu adalah pesan agen (isMe = true)
    // Cek juga nama field lama untuk kompatibilitas mundur
    bool isMe = false;
    if (!isSystem) {
      final agentIdVal = json['AgentId'];
      if (agentIdVal != null && agentIdVal != 0 && agentIdVal.toString() != '0') {
        // AgentId ada dan bukan 0 → pesan dikirim oleh agen (kita)
        isMe = true;
      } else if (json['IsMe'] == true) {
        isMe = true;
      } else {
        // Fallback: cek kecocokan email
        final senderId = json['SenderId']?.toString() ?? json['FromId']?.toString() ?? json['sender_email'] ?? '';
        isMe = senderId == currentUserEmail;
      }
    }

    // Parse file media — cek array Files terlebih dahulu, lalu field File, lalu fallback berdasarkan Type
    MessageType msgType = MessageType.text;
    String? imgUrl;
    String? audioPath;
    String? videoUrl;
    
    // Helper untuk mengecek apakah nama file adalah video
    bool isVideoFile(String fileName) {
      final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      return ['mp4', 'avi', 'mov', 'mkv', '3gp', 'webm', 'ogg_video'].contains(ext);
    }
    
    // Helper untuk mengecek apakah nama file adalah file audio
    bool isAudioFile(String fileName) {
      final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      return ['mp3', 'wav', 'ogg', 'oga', 'opus', 'm4a', 'aac', 'weba', 'amr'].contains(ext);
    }

    // Helper untuk mengecek flag Ptt:true (Voice Note marker dari WhatsApp/Telegram)
    bool _isPttFile(dynamic fileData) {
      if (fileData == null) return false;
      try {
        final decoded = fileData is String ? jsonDecode(fileData) : fileData;
        if (decoded is Map) {
          final isPttMap = decoded['Ptt'] == true || decoded['ptt'] == true || decoded['IsPtt'] == true || decoded['isPtt'] == true || decoded['IsAudio'] == true || decoded['isAudio'] == true || decoded['Ptt']?.toString().toLowerCase() == 'true' || decoded['ptt']?.toString().toLowerCase() == 'true';
          if (isPttMap) return true;
        }
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          final first = decoded.first;
          return first['Ptt'] == true || first['ptt'] == true || first['IsPtt'] == true || first['isPtt'] == true || first['IsAudio'] == true || first['isAudio'] == true || first['Ptt']?.toString().toLowerCase() == 'true' || first['ptt']?.toString().toLowerCase() == 'true';
        }
      } catch (_) {}
      return false;
    }

    // Helper to check for IsDocument: true flag
    bool _isDocumentFlag(dynamic fileData) {
      if (fileData == null) return false;
      try {
        final decoded = fileData is String ? jsonDecode(fileData) : fileData;
        if (decoded is Map) return decoded['IsDocument'] == true;
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          return decoded.first['IsDocument'] == true;
        }
      } catch (_) {}
      return false;
    }

    // Debug: catat raw JSON untuk pesan terkait media
    if (typeVal == '2' || typeVal == '16' || typeVal == '3' || typeVal == '4' || typeVal == '5' ||
        json['Files'] != null || json['File'] != null) {
      assert(() {
        debugPrint('Message.fromJson MEDIA: Type=$typeVal, Files=${json['Files']}, File=${json['File']}, Id=${json['Id']}, IdAlias=${json['IdAlias']}, tenantId=$tenantId, Msg=${json['Msg']}');
        return true;
      }());
    }

    // Helper untuk mengekstrak path file dari array Files atau field File
    String extractFilePath(dynamic fileData) {
      String filePath = fileData.toString();
      
      // Perbaikan untuk bug serialisasi backend yang mengirimkan nama class alih-alih file
      if (filePath.contains('NoboxWhatsapp') || filePath.contains('MessageResponse')) {
        return '';
      }

      if (fileData is Map) {
        if (fileData['Filename'] != null) filePath = fileData['Filename'].toString();
        else if (fileData['url'] != null) filePath = fileData['url'].toString();
      } else if (filePath.startsWith('{') || filePath.startsWith('[')) {
        try {
          final decoded = jsonDecode(filePath);
          final fileMap = decoded is List ? (decoded.isNotEmpty ? decoded.first : {}) : decoded;
          if (fileMap is Map) {
            if (fileMap['Filename'] != null) filePath = fileMap['Filename'].toString();
            else if (fileMap['url'] != null) filePath = fileMap['url'].toString();
          }
        } catch (_) {}
      }
      
      // Bersihkan tipe MIME atau parameter query (misal: .ogg; codecs=opus)
      if (filePath.contains(';')) {
        filePath = filePath.split(';').first;
      }
      if (filePath.contains('?')) {
        filePath = filePath.split('?').first;
      }
      return filePath.trim();
    }

    String extractOriginalName(dynamic fileData) {
      if (fileData is Map) {
        return fileData['OriginalName']?.toString() ?? '';
      } else if (fileData is String && (fileData.startsWith('{') || fileData.startsWith('['))) {
        try {
          final decoded = jsonDecode(fileData);
          final fileMap = decoded is List ? (decoded.isNotEmpty ? decoded.first : {}) : decoded;
          if (fileMap is Map) {
            return fileMap['OriginalName']?.toString() ?? '';
          }
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
      // Deteksi stiker PERTAMA (typeVal == '16') — sebelum pengecekan ekstensi
      if (typeVal == '16' && filePath.isNotEmpty) {
        msgType = MessageType.sticker;
        imgUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
        content = '🌟 Sticker';
      } else if (isAudioFile(filePath) || isAudioFile(originalName) || _isPttFile(firstFile) || originalName.toLowerCase().contains('voice note') || originalName.toLowerCase().contains('pesan suara') || filePath.toLowerCase().contains('voice note') || originalName.toLowerCase().contains('voice_') || filePath.toLowerCase().contains('voice_')) {
        // Voice note: cek ekstensi audio ATAU flag Ptt:true ATAU nama file mengandung voice note — SEBELUM cek document (type 5)
        // Server NoBox kadang mengembalikan Type=5 untuk voice notes
        msgType = MessageType.voice;
        audioPath = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
        content = '';
      } else if (typeVal == '5' || _isDocumentFlag(firstFile)) {
        // Jika dari API diset sebagai Dokumen (5) atau ada flag IsDocument: true
        msgType = MessageType.document;
        docName = originalName.isNotEmpty ? originalName : filePath.split('/').last;
        docUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
        content = '📄 $docName';
      } else if (isVideoFile(filePath) || isVideoFile(originalName)) {
        msgType = MessageType.video;
        videoUrl = filePath.startsWith('http') 
            ? filePath 
            : 'https://id.nobox.ai/upload/$filePath';
        if (filePath.toLowerCase().endsWith('.webm') || originalName.toLowerCase().endsWith('.webm')) {
          content = '🌟 Sticker';
        } else {
          content = '📹 Video';
        }
      } else if (_isImageFile(filePath) || _isImageFile(originalName)) {
        msgType = MessageType.image;
        imgUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
      } else if (typeVal == '2') {
        // Fallback berdasarkan API Type saat ekstensi tidak dikenali
        if (filePath.isNotEmpty || content.isEmpty || content.startsWith('{') || content.startsWith('[') || content.contains('Voice Note') || content.contains('🎵')) {
          msgType = MessageType.voice;
          audioPath = filePath.startsWith('http') || filePath.isEmpty ? filePath : 'https://id.nobox.ai/upload/$filePath';
          content = '';
        } else {
          msgType = MessageType.text; // Ignore buggy Type=2 if it's clearly a text message
        }
      } else if (typeVal == '4') {
        msgType = MessageType.video;
        videoUrl = filePath.startsWith('http') 
            ? filePath 
            : 'https://id.nobox.ai/upload/$filePath';
        if (filePath.toLowerCase().endsWith('.webm') || originalName.toLowerCase().endsWith('.webm')) {
          content = '🌟 Sticker';
        } else {
          content = '📹 Video';
        }
      } else if (typeVal == '3') {
        msgType = MessageType.image;
        imgUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
      } else if (typeVal == '15' || typeVal == '11' || (json['Msg'] != null && json['Msg'].toString().toLowerCase().contains('"lat":'))) {
        msgType = MessageType.text;
        content = '📍 Location';
      } else if (typeVal == '14' || typeVal == '10') {
        msgType = MessageType.text;
        content = '👤 Contact';
      } else if (filePath.isNotEmpty) {
        docName = originalName.isNotEmpty ? originalName : filePath.split('/').last;
        if (docName.toLowerCase().contains('document(empty)')) {
          msgType = MessageType.text;
          // Pertahankan text content aslinya (kemungkinan ini adalah Link / Caption / Teks lokasi)
          if (content.isEmpty || content.startsWith('{') || content.startsWith('[')) {
            content = '📍 Location';
          }
        } else {
          msgType = MessageType.document;
          docUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
          content = '📄 $docName';
        }
      }
    } else if (json['File'] != null && json['File'].toString().isNotEmpty) {
      final filePath = extractFilePath(json['File']);
      final originalName = extractOriginalName(json['File']);
      // Sticker detection FIRST (typeVal == '16') — before extension checks
      if (typeVal == '16' && filePath.isNotEmpty) {
        msgType = MessageType.sticker;
        imgUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
        content = '🌟 Sticker';
      } else if (typeVal == '2' || isAudioFile(filePath) || isAudioFile(originalName) || _isPttFile(json['File']) || originalName.toLowerCase().contains('voice note') || originalName.toLowerCase().contains('pesan suara') || filePath.toLowerCase().contains('voice note') || originalName.toLowerCase().contains('voice_') || filePath.toLowerCase().contains('voice_')) {
        // Voice note: cek typeVal=='2', ekstensi audio, nama file, ATAU flag Ptt:true — sebelum cek document (type 5)
        if (filePath.isNotEmpty || content.isEmpty || content.startsWith('{') || content.startsWith('[') || isAudioFile(filePath) || isAudioFile(originalName) || _isPttFile(json['File']) || originalName.toLowerCase().contains('voice note') || originalName.toLowerCase().contains('pesan suara') || filePath.toLowerCase().contains('voice note') || originalName.toLowerCase().contains('voice_') || filePath.toLowerCase().contains('voice_')) {
          msgType = MessageType.voice;
          audioPath = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
          content = '';
        } else {
          msgType = MessageType.text;
        }
      } else if (typeVal == '5' || _isDocumentFlag(json['File'])) {
        docName = originalName.isNotEmpty ? originalName : filePath.split('/').last;
        if (docName.toLowerCase().contains('document(empty)')) {
          msgType = MessageType.text;
          if (content.isEmpty || content.startsWith('{') || content.startsWith('[')) {
            content = '📍 Location';
          }
        } else {
          msgType = MessageType.document;
          docUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
          content = '📄 $docName';
        }
      } else if (isVideoFile(filePath) || isVideoFile(originalName)) {
        msgType = MessageType.video;
        videoUrl = filePath.startsWith('http') 
            ? filePath 
            : 'https://id.nobox.ai/upload/$filePath';
        if (filePath.toLowerCase().endsWith('.webm') || originalName.toLowerCase().endsWith('.webm')) {
          content = '🌟 Sticker';
        } else {
          content = '📹 Video';
        }
      } else if (_isImageFile(filePath) || _isImageFile(originalName)) {
        msgType = MessageType.image;
        imgUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
      } else if (typeVal == '4') {
        msgType = MessageType.video;
        videoUrl = filePath.startsWith('http') 
            ? filePath 
            : 'https://id.nobox.ai/upload/$filePath';
        if (filePath.toLowerCase().endsWith('.webm') || originalName.toLowerCase().endsWith('.webm')) {
          content = '🌟 Sticker';
        } else {
          content = '📹 Video';
        }
      } else if (typeVal == '3') {
        msgType = MessageType.image;
        imgUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
      } else if (typeVal == '15' || typeVal == '11' || (json['Msg'] != null && json['Msg'].toString().toLowerCase().contains('"lat":'))) {
        msgType = MessageType.text;
        content = '📍 Location';
      } else if (typeVal == '14' || typeVal == '10') {
        msgType = MessageType.text;
        content = '👤 Contact';
      } else if (filePath.isNotEmpty) {
        docName = originalName.isNotEmpty ? originalName : filePath.split('/').last;
        if (docName.toLowerCase().contains('document(empty)')) {
          msgType = MessageType.text;
          if (content.isEmpty || content.startsWith('{') || content.startsWith('[')) {
            content = '📍 Location';
          }
        } else {
          msgType = MessageType.document;
          docUrl = filePath.startsWith('http') ? filePath : 'https://id.nobox.ai/upload/$filePath';
          content = '📄 $docName';
        }
      }
    } else if (typeVal == '2' || content.contains('🎵 Voice Note')) {
      msgType = MessageType.voice;
      audioPath = '';
      content = '';
    } else if (typeVal == '16' || typeVal == '3') {
      // No Files/File data available
      msgType = MessageType.text;
      if (content.isEmpty || content.startsWith('{') || content.startsWith('[')) {
        content = '⚠️ Pesan ini tidak dapat ditampilkan. Buka WhatsApp di HP untuk melihat pesan ini.';
      }
    } else if (typeVal == '15' || typeVal == '11') {
      msgType = MessageType.text;
      content = '📍 Location';
    } else if (typeVal == '14' || typeVal == '10') {
      msgType = MessageType.text;
      content = '👤 Contact';
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

    // FIX: Parse pesan balasan (Reply Context) agar tidak hilang saat keluar masuk halaman
    Message? parsedRepliedMsg;
    if (json['ReplyMsg'] != null && json['ReplyMsg'].toString().isNotEmpty) {
      parsedRepliedMsg = Message(
        id: json['ReplyId']?.toString() ?? '',
        content: json['ReplyMsg']?.toString() ?? '',
        isMe: json['ReplyFrom']?.toString() == currentUserEmail,
        time: '', // Waktu tidak dikirimkan oleh API untuk pesan balasan
        rawTime: '',
      );
    }

    return Message(
      id: id,
      content: content,
      isMe: isMe,
      time: formattedTime,
      rawTime: rawTime,
      status: MessageStatus.read,
      isSystemMessage: isSystem,
      messageType: msgType,
      imageUrl: imgUrl,
      audioPath: audioPath,
      videoUrl: videoUrl,
      documentName: docName,
      documentUrl: docUrl,
      ack: parsedAck,
      repliedMessage: parsedRepliedMsg,
    );
  }

  Message copyWith({
    String? id,
    String? content,
    bool? isMe,
    String? time,
    String? rawTime,
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
      rawTime: rawTime ?? this.rawTime,
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
