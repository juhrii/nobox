import 'package:flutter/material.dart';

class QuickReplyOverlay extends StatefulWidget {
  final Function(String) onSelectReply;

  const QuickReplyOverlay({
    super.key,
    required this.onSelectReply,
  });

  @override
  State<QuickReplyOverlay> createState() => _QuickReplyOverlayState();
}

class _QuickReplyOverlayState extends State<QuickReplyOverlay> {
  final TextEditingController _searchController = TextEditingController();
  
  // Mock Data
  final List<Map<String, String>> _allRepliesMock = [
    {'title': 'Greeting', 'content': 'Halo, ada yang bisa kami bantu hari ini?'},
    {'title': 'Pricing', 'content': 'Berikut adalah daftar harga layanan kami:\n1. Basic: Rp100k\n2. Pro: Rp200k'},
    {'title': 'Closing', 'content': 'Terima kasih telah menghubungi kami. Semoga harinya menyenangkan!'},
    {'title': 'Address', 'content': 'Kantor kami berlokasi di Jl. Sudirman No.1, Jakarta Pusat.'},
  ];
  
  List<Map<String, String>> _filteredReplies = [];

  @override
  void initState() {
    super.initState();
    _filteredReplies = _allRepliesMock;
    
    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredReplies = _allRepliesMock.where((reply) {
          final title = reply['title']!.toLowerCase();
          final content = reply['content']!.toLowerCase();
          return title.contains(query) || content.contains(query);
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Quick Replies',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search reply...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey.shade800 
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredReplies.isEmpty
                ? const Center(child: Text('No quick replies found.'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredReplies.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final reply = _filteredReplies[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        title: Text(
                          reply['title']!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          reply['content']!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          widget.onSelectReply(reply['content']!);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
