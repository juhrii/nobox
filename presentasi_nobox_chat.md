# Teks Presentasi — Hasil Project NoBox Chat

---

Baik, saya akan menjelaskan hasil dari project aplikasi NoBox Chat yang telah kami kembangkan.

## Splash Screen

Ketika pertama kali membuka aplikasi, pengguna akan disambut oleh splash screen yang menampilkan logo NoBox beserta nama aplikasi "NoBoxChat" dan tagline "Professional Chat Management". Di bagian bawah terdapat loading animation yang menunjukkan aplikasi sedang memproses. Splash screen ini secara otomatis mengecek apakah pengguna sudah pernah login sebelumnya atau belum. Jika sudah login, pengguna akan langsung diarahkan ke halaman chat list. Jika belum, maka akan diarahkan ke halaman login.

## Login

Di halaman login, pengguna diminta memasukkan email dan password. Sistem akan melakukan validasi input — jika ada field yang kosong, akan muncul pesan error. Setelah login berhasil, token autentikasi akan disimpan secara lokal sehingga pengguna tidak perlu login ulang setiap membuka aplikasi.

## Halaman Chat List

Ini adalah halaman utama aplikasi. Di bagian atas terdapat AppBar berwarna biru dengan logo NoBox dan judul "NoBox Chat". Di sebelah kanan ada tiga icon:

Pertama, icon **Search** yang ketika ditekan akan membuka dialog pencarian untuk mencari percakapan berdasarkan nama atau isi pesan.

Kedua, icon **Filter** yang membuka dialog "Filter Conversation". Di sini pengguna bisa memfilter percakapan berdasarkan berbagai kriteria seperti Status, Read Status, Channel, Account, Contact, dan lain-lain. Ada tombol Apply untuk menerapkan filter dan tombol Reset untuk mengembalikan ke tampilan semua percakapan.

Ketiga, icon **titik tiga** yang berisi menu Pengaturan dan Logout.

Di bawah AppBar terdapat **TabBar** dengan empat tab: All, Unassigned, Assigned, dan Resolved. Tab ini memungkinkan pengguna untuk memfilter percakapan berdasarkan status penanganan secara cepat.

Untuk setiap item chat, kami menampilkan informasi yang cukup lengkap. Ada avatar, nama pengirim, timestamp, preview pesan terakhir, tags atau label percakapan, nama agent yang menangani beserta icon WhatsApp, dan juga status badge yang diberi warna berbeda — hijau untuk Resolved, biru untuk Assigned, dan oranye untuk Unassigned. Jika ada pesan yang belum dibaca, badge jumlahnya juga ditampilkan.

Di pojok kanan bawah ada tombol **FAB plus** yang ketika ditekan akan membuka dialog "New Conversation". Di dialog ini pengguna bisa memilih tipe chat apakah Private atau Group, memilih channel seperti WhatsApp, Telegram, Email, atau Web, memilih akun, menentukan tujuan apakah dari Contact, Link, atau Manual, dan juga memilih kontak tujuan.

Selain itu, halaman chat list juga mendukung pull-to-refresh untuk memuat ulang data, swipe untuk mengarsipkan chat, dan long press untuk opsi pin atau arsip.

## Halaman Chat Detail

Ketika pengguna menekan salah satu percakapan, akan masuk ke halaman chat detail. Di sini terdapat AppBar dengan avatar dan nama kontak. Bubble chat menggunakan dua warna yaitu putih untuk pesan masuk dan biru untuk pesan keluar.

Fitur-fitur yang tersedia di halaman ini antara lain: pengiriman pesan teks, perekaman dan pengiriman voice message dengan tombol record dan playback, emoji picker untuk memilih emoji, fitur reply atau quote untuk membalas pesan tertentu, serta system message yang ditampilkan di tengah percakapan.

## Settings

Di halaman pengaturan, pengguna bisa mengaktifkan atau menonaktifkan Dark Mode. Perubahan tema ini akan langsung diterapkan ke seluruh tampilan aplikasi dan disimpan secara lokal.

## Fitur Teknis

Dari sisi teknis, aplikasi ini menggunakan Flutter sebagai framework, terintegrasi penuh dengan REST API NoBox menggunakan Dio sebagai HTTP client, mendukung real-time messaging melalui SignalR dengan metode Long Polling, menggunakan Provider pattern untuk state management, dan mendukung dua platform yaitu Android dan Windows Desktop.

## Kesimpulan

Secara keseluruhan, NoBox Chat adalah aplikasi chat management profesional yang memiliki 6 halaman utama, 3 dialog interaktif, dan berbagai fitur chat seperti pengiriman teks, voice message, emoji, reply, pin, arsip, dan custom background. Aplikasi ini dibangun dengan arsitektur yang terstruktur dan terintegrasi langsung dengan sistem NoBox.

Demikian penjelasan hasil dari project NoBox Chat. Terima kasih.
