import os

comments = {
    "lib/presentation/screens/splash/splash_page.dart": """// =====================================================================
// FITUR 1: Splash & Autentikasi Pengguna (Login)
// TUJUAN: Memvalidasi kredensial pengguna, mengarahkan navigasi pertama kali saat aplikasi dibuka, dan menginisialisasi tema aplikasi.
// CARA KERJA: initState() memanggil _checkLogin(). Aplikasi memuat token pengguna (checkAuth()), preferensi tema (loadTheme()), dan pengaturan chat secara paralel. Jika sudah login, masuk ke home dan panggil SignalRService().connect().
// =====================================================================
""",
    "lib/presentation/screens/auth/login_page.dart": """// =====================================================================
// FITUR 1: Autentikasi Pengguna (Login Page)
// TUJUAN: Memvalidasi kredensial pengguna dan mengelola fitur "Remember Email".
// CARA KERJA: Menyediakan checkbox "Remember Email" yang menyimpan data input pengguna ke penyimpanan lokal (SharedPreferences) jika dicentang, sehingga saat aplikasi dibuka kembali, kolom email terisi secara otomatis.
// =====================================================================
""",
    "lib/core/providers/auth_provider.dart": """// =====================================================================
// FITUR 1: Autentikasi Pengguna (Auth Provider)
// TUJUAN: Mengelola state login pengguna, menyimpan token JWT, dan memvalidasi kredensial.
// =====================================================================
""",
    "lib/core/utils/app_validator.dart": """// =====================================================================
// FITUR 1: Validasi Input (App Validator)
// TUJUAN: Melakukan validasi input form (seperti email dan password) secara seragam di seluruh aplikasi.
// =====================================================================
""",
    "lib/presentation/widgets/chat_list_skeleton.dart": """// =====================================================================
// FITUR 2: Daftar Obrolan Utama (Chat List Skeleton)
// TUJUAN: Menampilkan efek visual loading (shimmer) saat data ruang percakapan sedang diambil dari server.
// =====================================================================
""",
    "lib/core/services/signalr_service.dart": """// =====================================================================
// FITUR 3: Sinkronisasi Real-Time (SignalR Integration)
// TUJUAN: Menerima pesan chat baru dan menyinkronkan status obrolan secara instan tanpa memuat ulang layar.
// CARA KERJA: SignalRService terhubung ke server hub SignalR menggunakan Token JWT setelah login berhasil. Mendengarkan event TerimaSubSpv dan TerimaPesan lalu meneruskannya via stream.
// =====================================================================
""",
    "lib/presentation/widgets/message_bubble_widget.dart": """// =====================================================================
// FITUR 4: Detail Ruang Obrolan (Message Bubble Widget)
// TUJUAN: Mengelola antarmuka visual satu gelembung pesan, termasuk teks, media, jam pengiriman, dan indikator centang baca.
// CARA KERJA: Centang dipetakan berdasarkan status ack: 1 (Abu 1), 2 (Abu 2), 3 (Biru 2).
// =====================================================================
""",
    "lib/presentation/widgets/quick_reply_overlay.dart": """// =====================================================================
// FITUR 5: Pintasan Balas Cepat (Quick Reply Template)
// TUJUAN: Memudahkan agen membalas pesan secara cepat dengan template tulisan siap pakai.
// CARA KERJA: Muncul sebagai overlay saat pengguna mengetik karakter '/' di kolom input chat. Saat diketuk, mengganti teks input secara instan.
// =====================================================================
""",
    "lib/presentation/widgets/channel_icon.dart": """// =====================================================================
// FITUR 6: Integrasi Saluran Multi-Platform (Channel Icon)
// TUJUAN: Mengidentifikasi dan menampilkan ikon visual asal saluran chat (platform) dari pelanggan.
// CARA KERJA: Memetakan chId ke aset gambar yang sesuai (WhatsApp, Telegram, IG, dsb) secara dinamis.
// =====================================================================
""",
    "lib/presentation/widgets/voice_recording_bottom_sheet.dart": """// =====================================================================
// FITUR 8: Perekaman Voice Note (Voice Recording)
// TUJUAN: Mengirimkan pesan suara interaktif di dalam chat.
// CARA KERJA: Bottom sheet ini memanfaatkan library record untuk merekam suara mikrofon langsung ke format berkas .m4a dan membatasi perekaman dengan durasi visual.
// =====================================================================
""",
    "lib/presentation/widgets/audio_player_widget.dart": """// =====================================================================
// FITUR 8: Pemutaran Voice Note (Audio Player Widget)
// TUJUAN: Memutar pesan suara interaktif di dalam chat.
// CARA KERJA: Menggunakan library audioplayers untuk memuat URL audio, menampilkan kontrol play/pause, slider posisi player, dan durasi berjalan.
// =====================================================================
""",
    "lib/presentation/widgets/searchable_dropdown.dart": """// =====================================================================
// FITUR 10: Filter Obrolan Lanjutan (Searchable Dropdown)
// TUJUAN: Komponen UI untuk menyaring daftar obrolan berdasarkan banyak kriteria dengan kemampuan pencarian teks.
// =====================================================================
""",
    "lib/presentation/widgets/add_note_dialog.dart": """// =====================================================================
// FITUR 13: Catatan Internal (Add Note Dialog)
// TUJUAN: Menampilkan dialog input bagi agen untuk menambahkan catatan internal terkait seorang pelanggan.
// =====================================================================
""",
    "lib/presentation/widgets/tag_selection_dialog.dart": """// =====================================================================
// FITUR 13: Manajemen Kontak (Tag Selection Dialog)
// TUJUAN: Antarmuka bagi agen untuk memilih atau melabeli kategori tag prospek kepada pelanggan (misal: "Hot Lead").
// =====================================================================
""",
    "lib/core/services/contact_detail_service.dart": """// =====================================================================
// FITUR 13: Manajemen Kontak (Contact Detail Service)
// TUJUAN: API Service untuk mengambil detail lengkap kontak, mengedit data, serta mengelola catatan dan tag pelanggan.
// =====================================================================
"""
}

for filepath, comment in comments.items():
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if already commented
        if "FITUR" not in content[:500]:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(comment + content)
            print(f"Added comment to {filepath}")
    else:
        print(f"File not found: {filepath}")
