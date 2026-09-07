import 'package:intl/intl.dart';

void main() {
  var t1 = DateTime(2026, 9, 7, 13, 0);
  print('HH:mm -> ${DateFormat('HH:mm').format(t1)}');
  print('hh:mm -> ${DateFormat('hh:mm').format(t1)}');
  print('hh:mm a -> ${DateFormat('hh:mm a').format(t1)}');
}
