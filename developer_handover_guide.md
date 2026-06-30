# Panduan Pengembangan Fitur (Developer Handover Guide)

Dokumen ini disusun khusus sebagai panduan serah terima (*handover*) agar developer penerus dapat memahami, merawat, dan mengembangkan kembali project NoBox Chat Basic secara modular berdasarkan per fitur.

---

## Daftar Isi Fitur
1. [Fitur 1: Splash & Autentikasi Pengguna (Login)](#fitur-1-splash--autentikasi-pengguna-login)
2. [Fitur 2: Daftar Obrolan Utama (Chat List) & Paging](#fitur-2-daftar-obrolan-utama-chat-list--paging)
3. [Fitur 3: Sinkronisasi Real-Time (SignalR Integration)](#fitur-3-sinkronisasi-real-time-signalr-integration)
4. [Fitur 4: Detail Ruang Obrolan & Status Pengiriman Pesan](#fitur-4-detail-ruang-obrolan--status-pengiriman-pesan)
5. [Fitur 5: Pintasan Balas Cepat (Quick Reply Template)](#fitur-5-pintasan-balas-cepat-quick-reply-template)
6. [Fitur 6: Integrasi Saluran Multi-Platform (WhatsApp, Telegram, Tokopedia, dll)](#fitur-6-integrasi-saluran-multi-platform-whatsapp-telegram-tokopedia-dll)
7. [Fitur 7: Pengiriman Gambar & File Lampiran](#fitur-7-pengiriman-gambar--file-lampiran)
8. [Fitur 8: Perekaman & Pemutaran Voice Note (Pesan Suara)](#fitur-8-perekaman--pemutaran-voice-note-pesan-suara)
9. [Fitur 9: Berbagi Lokasi Peta (Location Sharing)](#fitur-9-berbagi-lokasi-peta-location-sharing)
10. [Fitur 10: Filter Obrolan Lanjutan (Advanced Filter)](#fitur-10-filter-obrolan-lanjutan-advanced-filter)
11. [Fitur 11: Pengarsipan Obrolan (Archive Chat)](#fitur-11-pengarsipan-obrolan-archive-chat)
12. [Fitur 12: Pesan Berbintang (Starred Messages)](#fitur-12-pesan-berbintang-starred-messages)
13. [Fitur 13: Manajemen Kontak & Catatan Internal (Contact Info & Notes)](#fitur-13-manajemen-kontak--catatan-internal-contact-info--notes)

---

### Fitur 1: Splash & Autentikasi Pengguna (Login)

*   **Tujuan**: Memvalidasi kredensial pengguna, mengarahkan navigasi pertama kali saat aplikasi dibuka, dan menginisialisasi tema aplikasi.
*   **Letak File UI**: 
    *   `lib/presentation/screens/splash/splash_page.dart`
    *   `lib/presentation/screens/auth/login_page.dart`
*   **Letak File Logika/State**: 
    *   `lib/core/providers/auth_provider.dart`
    *   `lib/core/utils/app_validator.dart` (Validasi form email/password)
*   **Cara Kerja & Penyambungan**:
    1.  Di Splash Page, `initState()` memanggil `_checkLogin()`. Aplikasi memuat token pengguna (`checkAuth()`), preferensi tema (`loadTheme()`), dan pengaturan chat secara paralel.
    2.  Jika sudah login, aplikasi masuk ke home dan memanggil `SignalRService().connect()`. Jika belum, dilempar ke rute login.
    3.  Di Login Page, terdapat checkbox "Remember Email" yang menyimpan data input pengguna ke penyimpanan lokal (SharedPreferences) jika dicentang, sehingga saat aplikasi dibuka kembali, kolom email terisi secara otomatis.

---

### Fitur 2: Daftar Obrolan Utama (Chat List) & Paging

*   **Tujuan**: Menampilkan daftar ruang percakapan aktif yang masuk ke sistem.
*   **Letak File UI**: 
    *   `lib/presentation/screens/chat/chat_list_page.dart`
    *   `lib/presentation/widgets/chat_list_skeleton.dart` (Tampilan *loading shimmer*)
*   **Letak File Logika/State**:
    *   `lib/core/providers/chat_provider.dart` (Metode `fetchChats` & `fetchMoreChats`)
*   **Cara Kerja & Penyambungan**:
    1.  Saat di-render, `ChatListPage` memanggil `chatProvider.fetchChats()` untuk mengambil 20 data percakapan pertama dari server.
    2.  Paging diimplementasikan menggunakan `ScrollController` di `ListView.builder`. Begitu posisi scroll mendekati bagian paling bawah (`pixels >= maxScrollExtent - 200`), fungsi `fetchMoreChats()` dipanggil untuk meminta data chat berikutnya dari server dengan parameter `skip` bertahap (kelipatan 20).

---

### Fitur 3: Sinkronisasi Real-Time (SignalR Integration)

*   **Tujuan**: Menerima pesan chat baru dan menyinkronkan status obrolan secara instan tanpa memuat ulang layar.
*   **Letak File Logika/Service**:
    *   `lib/core/services/signalr_service.dart`
    *   `lib/core/providers/chat_provider.dart` (Metode `updateRoomFromSignalR`)
*   **Cara Kerja & Penyambungan**:
    1.  `SignalRService` terhubung ke server hub SignalR menggunakan Token JWT setelah login berhasil.
    2.  Service mendengarkan event `TerimaSubSpv` (event status chat room global) dan `TerimaPesan` (pesan chat masuk).
    3.  Begitu data event diterima, data di-parse dan dikirim ke `ChatProvider` melalui fungsi stream. UI akan mendeteksi perubahan state dan melakukan *rebuild* (memperbarui jumlah unread, pesan terakhir, atau menyisipkan pesan baru secara langsung).

---

### Fitur 4: Detail Ruang Obrolan & Status Pengiriman Pesan

*   **Tujuan**: Mengelola antarmuka ruang chat detail, mengirim pesan teks, dan melacak tanda centang status pesan.
*   **Letak File UI**:
    *   `lib/presentation/screens/chat/chat_detail_page.dart`
    *   `lib/presentation/widgets/message_bubble_widget.dart` (Tampilan balon chat)
*   **Letak File Logika/State**:
    *   `lib/core/model/message.dart` (Status ack pemetaan centang)
*   **Cara Kerja & Penyambungan**:
    1.  Pengiriman pesan menggunakan `_chatService.sendMessage()`. Pesan baru ditambahkan ke tampilan lokal secara optimis (langsung muncul) dengan status centang 1 abu-abu.
    2.  Centang pesan dipetakan berdasarkan status `ack` dari database:
        *   `ack = 1` -> Centang 1 Abu-Abu (Terkirim ke server).
        *   `ack = 2` -> Centang 2 Abu-Abu (Terkirim ke server gateway).
        *   `ack = 3` -> Centang 2 Biru (Sudah terbaca oleh penerima).
    3.  Sebuah timer polling (`_startChatSyncPolling`) berjalan setiap 4 detik untuk memperbarui status centang di layar secara berkala jika ada perubahan ack dari backend.

---

### Fitur 5: Pintasan Balas Cepat (Quick Reply Template)

*   **Tujuan**: Memudahkan agen membalas pesan secara cepat dengan template tulisan siap pakai.
*   **Letak File UI**:
    *   `lib/presentation/widgets/quick_reply_overlay.dart`
*   **Letak File Logika/State**:
    *   `lib/presentation/screens/chat/chat_detail_page.dart` (Metode `_fetchQuickReplies`)
*   **Cara Kerja & Penyambungan**:
    1.  Aplikasi memasang listener pada input text controller di Chat Detail.
    2.  Jika input diawali karakter `/` (seperti `/salam`), state `_isShowingQuickReply` akan aktif dan memunculkan *overlay list* berisi template yang sudah di-cache.
    3.  Saat template diketuk, teks input di kolom chat otomatis digantikan dengan isi template penuh tersebut secara instan.

---

### Fitur 6: Integrasi Saluran Multi-Platform (WhatsApp, Telegram, Tokopedia, dll)

*   **Tujuan**: Mengidentifikasi dan menampilkan asal saluran chat (platform) dari pelanggan.
*   **Letak File UI**:
    *   `lib/presentation/widgets/channel_icon.dart`
*   **Letak File Logika/State**:
    *   `lib/core/services/chat_service.dart` (Metode `getChannels` & `getAccounts`)
*   **Cara Kerja & Penyambungan**:
    1.  Setiap percakapan membawa ID Saluran (`chId`) dan tipe saluran (`channelType`).
    2.  `ChannelIcon` memetakan parameter `chId` secara modular:
        *   ID 1 / 1557 / 1561 -> WhatsApp (`assets/wa.png`)
        *   ID 2 -> Telegram (`assets/telegram.png`)
        *   ID 3 / 4 -> Instagram / Facebook
        *   Mendeteksi kata seperti "tokopedia", "shopee", "tiktok" secara dinamis pada nama saluran untuk memunculkan ikon e-commerce yang relevan.

---

### Fitur 7: Pengiriman Gambar & File Lampiran

*   **Tujuan**: Memfasilitasi pengiriman file dokumen dan gambar di ruang obrolan.
*   **Letak File UI**:
    *   `lib/presentation/screens/chat/file_preview_screen.dart` (Halaman pratinjau sebelum kirim)
*   **Letak File Logika/State**:
    *   `lib/core/services/media_service.dart` (Metode upload file ke server)
*   **Cara Kerja & Penyambungan**:
    1.  Menggunakan package `image_picker` untuk mengambil foto via Kamera/Galeri, dan `file_picker` untuk memilih dokumen.
    2.  File yang dipilih dibawa ke `FilePreviewScreen` untuk dicek oleh pengguna.
    3.  Ketika dikonfirmasi, file diunggah ke server via API upload multipart. Tautan URL file yang dikembalikan server kemudian dikirim sebagai pesan chat dengan tipe data media terkait (Image/Document).

---

### Fitur 8: Perekaman & Pemutaran Voice Note (Pesan Suara)

*   **Tujuan**: Mengirimkan pesan suara interaktif di dalam chat.
*   **Letak File UI**:
    *   `lib/presentation/widgets/voice_recording_bottom_sheet.dart`
    *   `lib/presentation/widgets/audio_player_widget.dart`
*   **Cara Kerja & Penyambungan**:
    1.  Merekam: Bottom sheet memanfaatkan library `record` untuk merekam suara mikrofon langsung ke format berkas `.m4a` dan membatasi perekaman dengan durasi visual.
    2.  Mengirim: File suara diunggah ke server dan dikirimkan sebagai tipe pesan audio.
    3.  Memutar: Di sisi penerima/pengirim, `AudioPlayerWidget` yang menggunakan library `audioplayers` akan memuat URL audio tersebut, menampilkan kontrol play/pause, slider posisi player, dan durasi audio berjalan.

---

### Fitur 9: Berbagi Lokasi Peta (Location Sharing)

*   **Tujuan**: Mengirimkan titik koordinat lokasi fisik pengguna.
*   **Letak File UI**:
    *   `lib/presentation/screens/chat/location_picker_page.dart`
*   **Cara Kerja & Penyambungan**:
    1.  Membuka peta OSM menggunakan package map berbasis koordinat (`latlong2`).
    2.  User memosisikan pin di koordinat lokasi yang tepat.
    3.  Koordinat Latitude dan Longitude tersebut dikirim sebagai pesan teks terformat yang dapat diklik untuk membuka Google Maps secara eksternal (`url_launcher`).

---

### Fitur 10: Filter Obrolan Lanjutan (Advanced Filter)

*   **Tujuan**: Menyaring daftar obrolan berdasarkan banyak kriteria (Status, Akun, Channel, dll).
*   **Letak File UI**:
    *   `lib/presentation/widgets/searchable_dropdown.dart` (Dropdown dengan fitur cari)
*   **Letak File Logika/State**:
    *   `lib/core/providers/chat_provider.dart` (Getter `chats`)
*   **Cara Kerja & Penyambungan (Arsitektur Dua Jalur)**:
    1.  Jalur Server (Server-side): Pilihan filter seperti ID Akun, ID Kontak, ID Grup, ID Campaign, dan ID Deal dikirim langsung di parameter query API `get conversations` ke backend.
    2.  Jalur Aplikasi (Client-side): Pilihan filter seperti Mute AI, Tipe Chat (Group/Private), Status Terbaca (Is Read/Unread), Tag, Funnel, dan Link disaring secara lokal di aplikasi menggunakan fungsi `.where()` pada list chat room yang dikembalikan server.

---

### Fitur 11: Pengarsipan Obrolan (Archive Chat)

*   **Tujuan**: Menyembunyikan chat aktif ke ruang arsip dan mengembalikannya jika diperlukan.
*   **Letak File UI**:
    *   `lib/presentation/screens/chat/archive_list_page.dart`
*   **Letak File Logika/State**:
    *   `lib/core/providers/chat_provider.dart` (Metode `toggleArchive` & `getArchivedConversations`)
*   **Cara Kerja & Penyambungan**:
    1.  User melakukan *long press* di chat list untuk memilih chat lalu mengetuk ikon Archive.
    2.  Aplikasi menyimpan ID chat tersebut ke daftar arsip lokal (`_archivedIds` di Shared Preferences) dan memanggil API `getArchivedConversations()` untuk menyelaraskan dengan database server.
    3.  Di halaman `ArchiveListPage`, hanya obrolan dengan status `isArchived == true` yang ditampilkan. Pilihan Unarchive massal akan menghapus ID chat dari `_archivedIds` lokal dan memanggil kembali fungsi `toggleArchive` untuk menampilkannya di daftar chat utama.

---

### Fitur 12: Pesan Berbintang (Starred Messages)

*   **Tujuan**: Menyimpan pesan-pesan tertentu yang dianggap penting oleh user agar mudah dicari kembali.
*   **Letak File UI**:
    *   `lib/presentation/screens/chat/starred_messages_page.dart`
*   **Letak File Logika/State**:
    *   `lib/core/providers/chat_provider.dart` (Metode `toggleStar`)
*   **Cara Kerja & Penyambungan**:
    1.  Di dalam Chat Detail, user dapat mengetuk dan menahan balon pesan lalu memilih ikon bintang.
    2.  Pesan beserta metadatanya (pengirim, teks, waktu) ditambahkan ke dalam database lokal perangkat via SharedPreferences.
    3.  `StarredMessagesPage` memuat data list ini secara offline dan menampilkannya sebagai daftar pesan favorit yang dapat diklik untuk melompat kembali ke ruang chat bersangkutan.

---

### Fitur 13: Manajemen Kontak & Catatan Internal (Contact Info & Notes)

*   **Tujuan**: Melihat informasi pelanggan, mengedit nama/kontak, menetapkan Funnel & Tag prospek, serta menambahkan catatan internal tentang pelanggan tersebut.
*   **Letak File UI**:
    *   `lib/presentation/screens/chat/contact_info_page.dart`
    *   `lib/presentation/screens/chat/edit_contact_page.dart`
    *   `lib/presentation/widgets/add_note_dialog.dart`
    *   `lib/presentation/widgets/tag_selection_dialog.dart`
*   **Letak File Logika/State**:
    *   `lib/core/services/contact_detail_service.dart`
*   **Cara Kerja & Penyambungan**:
    1.  Detail Kontak: `ContactInfoPage` memuat profil lengkap pelanggan, termasuk akun sosial media terhubung dan riwayat catatan yang dibuat agen.
    2.  Edit Kontak: `EditContactPage` mengirim data nama, nomor HP, email, alamat, dll., ke server untuk diperbarui secara global.
    3.  Notes & Tags: Melalui dialog `AddNoteDialog` dan `TagSelectionDialog`, agen dapat menyematkan catatan internal (via NoteService) atau melabeli kategori pelanggan (misal: "Hot Lead", "Pelanggan Baru") yang disimpan langsung ke database pelanggan.
