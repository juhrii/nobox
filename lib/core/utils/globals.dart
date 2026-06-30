import 'package:flutter/material.dart';

// =====================================================================
// FITUR: Variabel Global Aplikasi
// FILE: lib/core/utils/globals.dart
// BARIS AWAL: 5 (setelah komentar ini)
// FUNGSI: Menyimpan GlobalKey untuk memungkinkan navigasi (Navigator) atau menampilkan pesan (Snackbar) dari luar konteks widget (contoh: dari dalam fungsi layanan/service).
// =====================================================================
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
