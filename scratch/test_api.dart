import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImN0eSI6IkpXVCJ9.eyJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcy9uYW1lIjoiYWtiYXJyaXlhbmRAZ21haWwuY29tIiwiaHR0cDovL3NjaGVtYXMueG1sc29hcC5vcmcvd3MvMjAwNS8wNS9pZGVudGl0eS9jbGFpbXMvbmFtZWlkZW50aWZpZXIiOiIxOTIwIiwiZXhwIjoxNzgwNTc1NjcxLCJpc3MiOiJodHRwczovL2lkLm5vYm94LmFpLyIsImF1ZCI6Imh0dHBzOi8vaWQubm9ib3guYWkvIn0.7fV6kU_7myFopRYxOWUk8hIcEL9vgB9Z5BmzWHvt-cU";
  final roomId = 807686061948933;
  
  Future<void> sendMsg(String name, Map<String, dynamic> payload) async {
    print("\n--- Testing " + name + " ---");
    final res = await http.post(
      Uri.parse('https://id.nobox.ai/Inbox/Send?Id=' + roomId.toString()),
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json'
      },
      body: jsonEncode(payload),
    );
    print("Send Response: " + res.statusCode.toString() + " " + res.body);
    
    // Check if it appeared in messages
    await Future.delayed(Duration(seconds: 2));
    final res2 = await http.post(
      Uri.parse('https://id.nobox.ai/Services/Chat/ChatMessages/List'),
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        "Take": 5, "Skip": 0, "Sort": ["In DESC"], "ColumnSelection": 1,
        "EqualityFilter": {"RoomId": [roomId]}
      }),
    );
    if (res2.statusCode == 200) {
      final json = jsonDecode(res2.body);
      final entities = json['Entities'] as List;
      if (entities.isNotEmpty) {
        print("Latest message in room: " + entities[0]['Msg'].toString());
      } else {
        print("No messages found in room");
      }
    } else {
      print("Failed to fetch messages: " + res2.statusCode.toString());
    }
  }

  // 5. JSON String ExtId, WITH LinkId
  await sendMsg("JSON String ExtId, WITH LinkId", {
    "Body": "test_json_string_with_lid",
    "BodyType": 1,
    "ExtId": "{\"ExtId\":\"6283146206451\",\"Username\":\"akbrryn\",\"AccessHash\":\"-8665298337796580198\"}",
    "ChannelId": 2,
    "AccountIds": "807236570021893",
    "Attachment": "",
    "LinkId": 807686061867013
  });

  // 6. JSON String ExtId but using IdExt instead of phone number
  await sendMsg("JSON String with IdExt inside, with LinkId", {
    "Body": "test_json_string_idext_inside",
    "BodyType": 1,
    "ExtId": "{\"ExtId\":\"6912143766\",\"Username\":\"akbrryn\",\"AccessHash\":\"-8665298337796580198\"}",
    "ChannelId": 2,
    "AccountIds": "807236570021893",
    "Attachment": "",
    "LinkId": 807686061867013
  });

  // 7. JSON String with IdExt inside, NO LinkId
  await sendMsg("JSON String with IdExt inside, NO LinkId", {
    "Body": "test_json_string_idext_inside_nolid",
    "BodyType": 1,
    "ExtId": "{\"ExtId\":\"6912143766\",\"Username\":\"akbrryn\",\"AccessHash\":\"-8665298337796580198\"}",
    "ChannelId": 2,
    "AccountIds": "807236570021893",
    "Attachment": ""
  });
}
