import 'dart:convert';

class QuickReplyTemplate {
  final String id;
  final String command;
  final String content;
  final String type;
  final List<String> files;
  final DateTime createdAt;
  final int createdBy;
  final DateTime updatedAt;
  final int updatedBy;

  QuickReplyTemplate({
    required this.id,
    required this.command,
    required this.content,
    required this.type,
    this.files = const [],
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory QuickReplyTemplate.fromJson(Map<String, dynamic> json) {
    // Parse files from JSON string
    List<String> fileList = [];
    try {
      if (json['Files'] != null && json['Files'] is String) {
        final filesStr = json['Files'] as String;
        if (filesStr.isNotEmpty && filesStr != '[]') {
          // Parse JSON array string
          final dynamic parsed = jsonDecode(filesStr);
          if (parsed is List) {
            fileList = parsed.map((e) => e.toString()).toList();
          }
        }
      }
    } catch (e) {
      print('Error parsing files for template ${json['Cmd']}: $e');
    }

    return QuickReplyTemplate(
      id: json['Id']?.toString() ?? '',
      command: json['Cmd']?.toString() ?? '',
      content: json['Cnt']?.toString() ?? '',
      type: json['Type']?.toString() ?? '1',
      files: fileList,
      createdAt: json['In'] != null 
          ? DateTime.parse(json['In']) 
          : DateTime.now(),
      createdBy: json['InBy'] ?? 0,
      updatedAt: json['Up'] != null 
          ? DateTime.parse(json['Up']) 
          : DateTime.now(),
      updatedBy: json['UpBy'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Cmd': command,
      'Cnt': content,
      'Type': type,
      'Files': jsonEncode(files),
      'In': createdAt.toIso8601String(),
      'InBy': createdBy,
      'Up': updatedAt.toIso8601String(),
      'UpBy': updatedBy,
    };
  }

  @override
  String toString() {
    return 'QuickReplyTemplate(id: $id, command: $command, content: $content)';
  }
}
