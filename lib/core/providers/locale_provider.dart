import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bahasa (locale) yang didukung
enum AppLocale { id, en }

// =====================================================================
// FITUR: Provider Bahasa (Locale)
// FILE: lib/core/providers/locale_provider.dart
// BARIS AWAL: 9 (setelah komentar ini)
// FUNGSI: Menyediakan fitur ganti bahasa aplikasi beserta penyimpanannya
// =====================================================================
class LocaleProvider with ChangeNotifier {
  static const String _localeKey = 'app_locale';
  AppLocale _locale = AppLocale.id; // Default: Bahasa Indonesia

  AppLocale get locale => _locale;
  bool get isEnglish => _locale == AppLocale.en;
  bool get isIndonesian => _locale == AppLocale.id;

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_localeKey);
    if (saved == 'en') {
      _locale = AppLocale.en;
    } else {
      _locale = AppLocale.id;
    }
    notifyListeners();
  }

  Future<void> setLocale(AppLocale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale == AppLocale.en ? 'en' : 'id');
    notifyListeners();
  }

  Future<void> toggleLocale() async {
    await setLocale(_locale == AppLocale.id ? AppLocale.en : AppLocale.id);
  }

  // FITUR: Ambil Terjemahan
  /// Mengambil string terjemahan berdasarkan kunci (key)
  String t(String key) {
    final map = _locale == AppLocale.id ? _id : _en;
    return map[key] ?? key;
  }

  // ─── Indonesian Strings ───
  static const Map<String, String> _id = {
    // App
    'app_title': 'NoBox Chat',

    // Chat List
    'search_hint': 'Cari chat...',
    'no_chats': 'Tidak ada chat',
    'retry': 'Coba Lagi',
    'archived': 'Diarsipkan',
    'new_conversation': 'Percakapan Baru',

    // Tabs
    'tab_all': 'Semua',
    'tab_unassigned': 'Belum Ditugaskan',
    'tab_assigned': 'Ditugaskan',
    'tab_resolved': 'Selesai',

    // Menu
    'profile': 'Profil',
    'settings': 'Pengaturan',
    'logout': 'Keluar',
    'logout_confirm': 'Yakin ingin keluar dari akun?',
    'cancel': 'Batal',

    // Chat Detail
    'type_message': 'Ketik pesan...',
    'no_more_messages': 'Tidak ada pesan lagi',
    'no_messages_yet': 'Belum ada pesan di sini.\nKetik sesuatu untuk memulai!',
    'clear_chat': 'Hapus Chat',
    'clear_chat_confirm': 'Yakin ingin menghapus semua pesan di percakapan ini?',
    'clear': 'Hapus',
    'chat_cleared': 'Chat dihapus',
    'choose_background': 'Pilih Background',
    'solid_colors': 'Warna Solid',
    'wallpaper': 'Wallpaper',
    'current': 'Saat ini',
    'send_failed': 'Gagal mengirim',
    'mic_permission': 'Izin mikrofon diperlukan untuk merekam suara',
    'upload_failed': 'Upload gagal',

    // Profile
    'edit_profile': 'Edit Profil',
    'change_password': 'Ubah Password',
    'available': 'Tersedia',
    'email': 'Email',
    'organization': 'Organisasi',
    'role': 'Role',
    'status': 'Status',
    'coming_soon_edit': 'Fitur edit profil segera hadir',
    'coming_soon_password': 'Fitur ubah password segera hadir',

    // Settings
    'dark_mode': 'Mode Gelap',
    'dark_on': 'Aktif',
    'dark_off': 'Nonaktif',
    'notifications': 'Notifikasi',
    'notifications_sub': 'Pesan, grup & nada dering',
    'storage': 'Penyimpanan dan Data',
    'storage_sub': 'Unduh otomatis, penggunaan jaringan',
    'help': 'Bantuan',
    'help_sub': 'Pusat bantuan, hubungi kami, kebijakan privasi',
    'language': 'Bahasa',
    'language_sub': 'Indonesia / English',

    // Filter
    'filter': 'Filter',
    'filter_status': 'Status',
    'filter_all': 'Semua Status',

    // New Conversation
    'chat_type': 'Jenis Chat',
    'channel': 'Channel',
    'account': 'Akun',
    'recipient': 'Penerima',
    'contact': 'Kontak',
    'manual': 'Manual',
    'link': 'Link',
    'create': 'Buat',
    'creating': 'Membuat...',
    'select_channel': 'Pilih Channel',
    'select_account': 'Pilih Akun',
    'select_contact': 'Pilih Kontak',
    'enter_id': 'Masukkan ID atau nomor',
  };

  // ─── English Strings ───
  static const Map<String, String> _en = {
    // App
    'app_title': 'NoBox Chat',

    // Chat List
    'search_hint': 'Search chats...',
    'no_chats': 'No chats found',
    'retry': 'Retry',
    'archived': 'Archived',
    'new_conversation': 'New Conversation',

    // Tabs
    'tab_all': 'All',
    'tab_unassigned': 'Unassigned',
    'tab_assigned': 'Assigned',
    'tab_resolved': 'Resolved',

    // Menu
    'profile': 'Profile',
    'settings': 'Settings',
    'logout': 'Logout',
    'logout_confirm': 'Are you sure you want to log out?',
    'cancel': 'Cancel',

    // Chat Detail
    'type_message': 'Type a message...',
    'no_more_messages': 'No more messages',
    'no_messages_yet': 'No messages yet.\nType something to get started!',
    'clear_chat': 'Clear Chat',
    'clear_chat_confirm': 'Are you sure you want to delete all messages in this conversation?',
    'clear': 'Clear',
    'chat_cleared': 'Chat cleared',
    'choose_background': 'Choose Background',
    'solid_colors': 'Solid Colors',
    'wallpaper': 'Wallpaper',
    'current': 'Current',
    'send_failed': 'Failed to send',
    'mic_permission': 'Microphone permission required for voice recording',
    'upload_failed': 'Upload failed',

    // Profile
    'edit_profile': 'Edit Profile',
    'change_password': 'Change Password',
    'available': 'Available',
    'email': 'Email',
    'organization': 'Organization',
    'role': 'Role',
    'status': 'Status',
    'coming_soon_edit': 'Edit profile feature coming soon',
    'coming_soon_password': 'Change password feature coming soon',

    // Settings
    'dark_mode': 'Dark Mode',
    'dark_on': 'On',
    'dark_off': 'Off',
    'notifications': 'Notifications',
    'notifications_sub': 'Messages, groups & ringtones',
    'storage': 'Storage and Data',
    'storage_sub': 'Auto-download, network usage',
    'help': 'Help',
    'help_sub': 'Help center, contact us, privacy policy',
    'language': 'Language',
    'language_sub': 'Indonesia / English',

    // Filter
    'filter': 'Filter',
    'filter_status': 'Status',
    'filter_all': 'All Status',

    // New Conversation
    'chat_type': 'Chat Type',
    'channel': 'Channel',
    'account': 'Account',
    'recipient': 'Recipient',
    'contact': 'Contact',
    'manual': 'Manual',
    'link': 'Link',
    'create': 'Create',
    'creating': 'Creating...',
    'select_channel': 'Select Channel',
    'select_account': 'Select Account',
    'select_contact': 'Select Contact',
    'enter_id': 'Enter ID or number',
  };
}
