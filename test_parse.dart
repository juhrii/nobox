void main() {
  var d1 = DateTime.tryParse("2026-08-07 14:30:00Z");
  print(d1);
  var d2 = DateTime.tryParse("2026-08-07T14:30:00Z");
  print(d2);
  var d3 = DateTime.tryParse("2026-08-07T14:35");
  print(d3);
}
