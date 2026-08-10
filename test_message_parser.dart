import 'dart:convert';
import 'lib/core/model/message.dart';

void main() {
  // Test 1: Link in Files array
  final json1 = {
    "Id": 1,
    "Type": "2",
    "Msg": "",
    "Files": ["https://vt.tiktok.com/ZSjR/"]
  };
  final msg1 = Message.fromJson(json1, 'test', 'me@test.com');
  print("Test 1 - Type: ${msg1.messageType}, Content: ${msg1.content}, Audio: ${msg1.audioPath}");

  // Test 2: Link in File string
  final json2 = {
    "Id": 2,
    "Type": "2",
    "Msg": "",
    "File": "https://vt.tiktok.com/ZSjR/"
  };
  final msg2 = Message.fromJson(json2, 'test', 'me@test.com');
  print("Test 2 - Type: ${msg2.messageType}, Content: ${msg2.content}, Audio: ${msg2.audioPath}");

  // Test 3: Link in JSON string in File
  final json3 = {
    "Id": 3,
    "Type": "2",
    "Msg": "",
    "File": "{ \"Url\": \"https://vt.tiktok.com/ZSjR/\" }"
  };
  final msg3 = Message.fromJson(json3, 'test', 'me@test.com');
  print("Test 3 - Type: ${msg3.messageType}, Content: ${msg3.content}, Audio: ${msg3.audioPath}");

  // Test 4: Link in JSON string in Files
  final json4 = {
    "Id": 4,
    "Type": "2",
    "Msg": "",
    "Files": ["{ \"Url\": \"https://vt.tiktok.com/ZSjR/\" }"]
  };
  final msg4 = Message.fromJson(json4, 'test', 'me@test.com');
  print("Test 4 - Type: ${msg4.messageType}, Content: ${msg4.content}, Audio: ${msg4.audioPath}");
  
  // Test 5: What if Type is 2, Msg is empty, and NO file?
  final json5 = {
    "Id": 5,
    "Type": "2",
    "Msg": ""
  };
  final msg5 = Message.fromJson(json5, 'test', 'me@test.com');
  print("Test 5 - Type: ${msg5.messageType}, Content: ${msg5.content}, Audio: ${msg5.audioPath}");
}
