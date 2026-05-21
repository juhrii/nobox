import 'package:flutter/material.dart';
import '../../core/services/chat_service.dart';
import '../../core/model/quick_reply_model.dart';

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
  final ChatService _chatService = ChatService();
  
  List<QuickReplyTemplate> _allReplies = [];
  List<QuickReplyTemplate> _filteredReplies = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchQuickReplies();
    
    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredReplies = _allReplies.where((reply) {
          final title = reply.command.toLowerCase();
          final content = reply.content.toLowerCase();
          return title.contains(query) || content.contains(query);
        }).toList();
      });
    });
  }

  Future<void> _fetchQuickReplies() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _chatService.getQuickReplyTemplates(take: 50, skip: 0);
      if (!mounted) return;

      if (!response.isError && response.data != null) {
        setState(() {
          _allReplies = response.data!;
          _filteredReplies = _allReplies;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.error ?? 'Failed to load quick replies';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('QuickReplyOverlay: Error fetching templates: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred while loading quick replies.';
        _isLoading = false;
      });
    }
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
              enabled: !_isLoading,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetchQuickReplies,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredReplies.isEmpty) {
      return const Center(child: Text('No quick replies found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredReplies.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final reply = _filteredReplies[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          title: Text(
            reply.command,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            reply.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            widget.onSelectReply(reply.content);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
