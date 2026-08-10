void main() {
  print(DateTime.tryParse("2026-08-07 14:30:00")!.isUtc);
  print(DateTime.tryParse("2026-08-07 14:30:00")!.toUtc());
}
