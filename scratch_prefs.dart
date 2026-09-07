import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  final prefs = await SharedPreferences.getInstance();
  print('chat_time_format: ${prefs.getString('chat_time_format')}');
  print('chat_date_format: ${prefs.getString('chat_date_format')}');
}
