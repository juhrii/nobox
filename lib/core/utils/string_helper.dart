// =====================================================================
// FITUR: String Helper (Apostrophe & Entity Unescape)
// FILE: lib/core/utils/string_helper.dart
// FUNGSI: Membersihkan karakter string, escaped apostrophe (\', &#39;, &apos;),
//         dan entity HTML agar tampil rapi dan akurat di seluruh UI.
// =====================================================================

class StringHelper {
  /// Membersihkan tanda petik / apostrophe (\', &#39;, &apos;) dan entitas HTML
  /// agar karakter petik tampil sebagai "'" asli dan bukan string kosong ("") atau escaped ("\'").
  static String cleanApostrophe(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
