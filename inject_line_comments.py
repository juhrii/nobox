import os
import re

replacements = [
    {
        "file": "lib/core/providers/chat_provider.dart",
        "targets": [
            {
                "regex": r"(Future<void> fetchChats\(\) async {)",
                "comment": "  // FITUR 2: Mengambil daftar obrolan utama (20 data pertama) dari server.\n"
            },
            {
                "regex": r"(Future<void> fetchMoreChats\(\) async {)",
                "comment": "  // FITUR 2: Paging untuk mengambil data chat berikutnya berdasarkan posisi scroll.\n"
            },
            {
                "regex": r"(void updateRoomFromSignalR\(Map<String, dynamic> roomData\) {)",
                "comment": "  // FITUR 3: Menyinkronkan status obrolan secara instan dari event SignalR.\n"
            },
            {
                "regex": r"(Future<void> toggleArchive\(String chatId\) async {)",
                "comment": "  // FITUR 11: Menyembunyikan chat aktif ke ruang arsip dan mengembalikannya.\n"
            },
            {
                "regex": r"(void toggleStar\(String messageId, \{String\? content, String\? sender, String\? time\}\) {)",
                "comment": "  // FITUR 12: Menyimpan pesan-pesan tertentu yang dianggap penting oleh user.\n"
            }
        ]
    },
    {
        "file": "lib/core/services/signalr_service.dart",
        "targets": [
            {
                "regex": r"(Future<void> connect\(\) async {)",
                "comment": "  // FITUR 3: Terhubung ke server hub SignalR menggunakan Token JWT.\n"
            },
            {
                "regex": r"(_hubConnection\!.on\('TerimaSubSpv', \(arguments\) {)",
                "comment": "      // FITUR 3: Mendengarkan event status chat room global.\n"
            },
            {
                "regex": r"(_hubConnection\!.on\('TerimaPesan', \(arguments\) {)",
                "comment": "      // FITUR 3: Mendengarkan pesan chat masuk secara real-time.\n"
            }
        ]
    },
    {
        "file": "lib/presentation/screens/chat/chat_detail_page.dart",
        "targets": [
            {
                "regex": r"(void _startChatSyncPolling\(\) {)",
                "comment": "  // FITUR 4: Timer polling untuk memperbarui status centang di layar secara berkala.\n"
            },
            {
                "regex": r"(Future<void> _fetchQuickReplies\(\) async {)",
                "comment": "  // FITUR 5: Memuat template balasan cepat (Quick Reply) dari server.\n"
            }
        ]
    },
    {
        "file": "lib/core/services/chat_service.dart",
        "targets": [
            {
                "regex": r"(Future<ApiResponse<List<Map<String, dynamic>>>> getChannels\(\) async {)",
                "comment": "  // FITUR 6: Integrasi Saluran Multi-Platform (Mengambil daftar Channel).\n"
            },
            {
                "regex": r"(Future<ApiResponse<List<Map<String, dynamic>>>> getAccounts\(\) async {)",
                "comment": "  // FITUR 6: Integrasi Saluran Multi-Platform (Mengambil daftar Akun).\n"
            }
        ]
    }
]

for item in replacements:
    filepath = item["file"]
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        modified = False
        for target in item["targets"]:
            # Check if comment already exists to avoid duplicates
            if target["comment"].strip() not in content:
                # Find the target and insert comment above it
                new_content = re.sub(target["regex"], target["comment"] + r"\1", content)
                if new_content != content:
                    content = new_content
                    modified = True
        
        if modified:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Injected line comments into {filepath}")
    else:
        print(f"File not found: {filepath}")
