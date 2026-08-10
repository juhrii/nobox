bool _isWebLink(String str) {
  if (str.isEmpty) return false;
  final lower = str.toLowerCase();
  if (lower.startsWith('http')) return true;
  if (lower.startsWith('www.')) return true;
  if (lower.contains('tiktok.com') || lower.contains('tiktok.co') || lower.contains('instagram.com') || lower.contains('youtube.com') || lower.contains('youtu.be') || lower.contains('shopee.co') || lower.contains('tokopedia.com') || lower.contains('facebook.com') || lower.contains('twitter.com') || lower.contains('x.com')) return true;
  if (RegExp(r'^[a-zA-Z0-9-]+\.(com|id|net|org|co|io|me|be|xyz)(\/|$)').hasMatch(lower)) return true;
  return false;
}

void main() {
  print(_isWebLink("https://vt.tiktok.com/ZSjR/"));
  print(_isWebLink("vt.tiktok.com/ZSjR/"));
  print(_isWebLink("{ \"Url\": \"https://vt.tiktok.com/ZSjR/\" }"));
}
