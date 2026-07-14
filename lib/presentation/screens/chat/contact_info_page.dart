import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/model/message.dart';
import '../../../core/providers/chat_provider.dart';
import 'edit_contact_page.dart';
import 'conversation_history_page.dart';
import '../../widgets/tag_selection_dialog.dart';
import '../../widgets/add_funnel_dialog.dart';
import '../../../core/services/filter_api_service.dart';
import '../../../core/model/filter_data_item.dart';
import '../../../core/model/api_response.dart';

// =====================================================================
// FITUR: Halaman Detail Kontak (Info)
// FILE: lib/presentation/screens/chat/contact_info_page.dart
// FUNGSI: Menampilkan dan mengelola informasi rinci dari kontak/chat room,
//         termasuk tag, funnel, note, status, dan data profil pengguna.
// =====================================================================

/// Contact Detail page matching the Nobox app design.
/// Sections: Contact, Conversation, Funnel, Message Tags, Notes,
/// Campaign, Deal, Form Template, Form Result, Human Agent.
class ContactInfoPage extends StatefulWidget {
  final ChatModel chat;
  const ContactInfoPage({super.key, required this.chat});

  @override
  State<ContactInfoPage> createState() => _ContactInfoPageState();
}

class _ContactInfoPageState extends State<ContactInfoPage> {
  late bool _needReply;
  late bool _muteAIAgent;
  late bool _isBlocked;
  late String _currentAccount;
  late String _currentFunnel;
  late List<String> _currentTags;
  late String _currentNotes;
  late String _currentCampaign;
  late String _currentPipeline;
  late String _currentStage;
  late String _currentDeal;
  late String _currentFormTemplate;
  late String _currentFormResult;
  String _agentEmail = '';
  String _currentAgentName = '';
  String _contactCountry = '';
  String _contactState = '';
  String _contactCity = '';
  String? _currentAvatarUrl;
  
  // Cached data from DetailRoom
  List<Map<String, dynamic>> _availableTagsFromServer = [];
  List<Map<String, dynamic>> _availableFunnelsFromServer = [];

  // Funnel overlay
  final GlobalKey _funnelRowKey = GlobalKey();
  OverlayEntry? _funnelOverlayEntry;
  List<Map<String, String>> _cachedFunnelItems = [];

  @override
  void initState() {
    super.initState();
    _needReply = widget.chat.needReply;
    _muteAIAgent = widget.chat.muteAiAgent;
    _isBlocked = widget.chat.isBlocked;
    _currentAccount = 'Not Set';
    _currentFunnel = widget.chat.funnel;
    _currentTags = List.from(widget.chat.tags);
    _currentNotes = widget.chat.notes;
    // For now these are just local state, easily migratable to ChatModel if needed
    _currentCampaign = '';
    _currentPipeline = '';
    _currentStage = '';
    _currentDeal = '';
    _currentFormTemplate = '';
    _currentFormResult = '';
    _currentAgentName = widget.chat.agentName;
    _currentAvatarUrl = widget.chat.avatarUrl;
    
    // Fetch latest data from server
    _loadDetailRoom();
  }

  @override
  void dispose() {
    _dismissFunnelOverlay(updateState: false);
    super.dispose();
  }

  // FITUR: Sinkronisasi Data Room & Kontak (API Call)
  // FUNGSI: Menarik data terbaru dari server mengenai obrolan ini, termasuk tag, funnel, notes, status bot, dsb.
  Future<void> _loadDetailRoom() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final data = await chatProvider.getDetailRoom(widget.chat.id);
    debugPrint('ContactInfo: DetailRoom response keys: ${data?.keys.toList()}');
    if (data != null && mounted) {
      // Debug: print semua data untuk lihat field yang tersedia
      final roomData = data['Data'] ?? data;
      debugPrint('ContactInfo: Data keys: ${roomData is Map ? roomData.keys.toList() : "not a map"}');
      if (roomData is Map) {
        if (roomData['Room'] is Map) {
          debugPrint('ContactInfo: Room keys: ${(roomData['Room'] as Map).keys.toList()}');
        }
        if (roomData['ContactReal'] is Map) {
          debugPrint('ContactInfo: ContactReal keys: ${(roomData['ContactReal'] as Map).keys.toList()}');
          debugPrint('ContactInfo: ContactReal data: ${roomData['ContactReal']}');
        } else {
          debugPrint('ContactInfo: No ContactReal key found in Data');
        }
      }
      // PRE-FETCH MASTER TAGS SECARA UNCONDITIONAL
      // Agar _convertNamesToIds selalu memiliki akses ke seluruh daftar tag, bukan hanya tag yang ter-assign di chat ini.
      List<Map<String, dynamic>>? masterTagsFallback;
      try {
        final tagRes = await FilterApiService().getTags();
        if (!tagRes.isError && tagRes.data != null) {
          masterTagsFallback = tagRes.data!;
        }
      } catch (e) {
        debugPrint('ContactInfo: Gagal pre-fetch master tags: $e');
      }

      if (!mounted) return;

      setState(() {
        // roomData = data['Data'], room = data['Data']['Room']
        final room = roomData is Map ? (roomData['Room'] ?? {}) : {};

        // Funnel: dari Room → Fn atau FnId
        final fnName = room['Fn']?.toString() ?? room['FnNm']?.toString() ?? '';
        if (fnName.isNotEmpty) _currentFunnel = fnName;

        // Notes: dari Data → Notes (bisa list)
        final notesData = roomData is Map ? roomData['Notes'] : null;
        if (notesData is List && notesData.isNotEmpty) {
          // Ambil note terakhir
          final lastNote = notesData.last;
          _currentNotes = lastNote['Cnt']?.toString() ?? lastNote['Content']?.toString() ?? _currentNotes;
        } else if (notesData is String && notesData.isNotEmpty) {
          _currentNotes = notesData;
        }

        // Campaign: dari Data → Campaign atau Room
        final campaignData = roomData is Map ? roomData['Campaign'] : null;
        if (campaignData is Map) {
          _currentCampaign = campaignData['Name']?.toString() ?? campaignData['Nm']?.toString() ?? _currentCampaign;
        } else {
          final roomCampaign = room['Campaign']?.toString() ?? '';
          if (roomCampaign.isNotEmpty) _currentCampaign = roomCampaign;
        }

        // Deal: dari Data → Deal atau Room
        final dealData = roomData is Map ? roomData['Deal'] : null;
        if (dealData is Map) {
          _currentDeal = dealData['Name']?.toString() ?? dealData['Nm']?.toString() ?? _currentDeal;
        } else {
          final roomDeal = room['Deal']?.toString() ?? '';
          if (roomDeal.isNotEmpty) _currentDeal = roomDeal;
        }

        // Form Template
        _currentFormTemplate = data['FormTemplateName']?.toString() ?? _currentFormTemplate;
        
        // Tags: dari Data → Tags (list of tag objects)
        final serverTags = roomData is Map ? roomData['Tags'] : null;
        debugPrint('ContactInfo: Tags type=${serverTags.runtimeType}, data=$serverTags');
        
        // SELALU utamakan masterTagsFallback karena berisi SEMUA tag, 
        // sehingga fungsi _convertNamesToIds dapat memetakan nama ke ID dengan benar!
        if (masterTagsFallback != null && masterTagsFallback.isNotEmpty) {
          _availableTagsFromServer = masterTagsFallback;
          debugPrint('ContactInfo: Saved ${_availableTagsFromServer.length} tags from masterTagsFallback');
        } else if (serverTags is List && serverTags.isNotEmpty) {
          _availableTagsFromServer = serverTags.whereType<Map<String, dynamic>>().toList();
          debugPrint('ContactInfo: Saved ${_availableTagsFromServer.length} tags from serverTags');
        }
        
        // Set current tags (yang sudah di-assign ke chat ini) dari Room.TagsIds
        final roomTagsIds = room['TagsIds']?.toString() ?? '';
        if (roomTagsIds.isNotEmpty) {
          // TagsIds bisa berupa comma-separated IDs
          final assignedIds = roomTagsIds.split(',').map((t) => t.trim()).toSet();
          _currentTags = _availableTagsFromServer
              .where((t) => assignedIds.contains(t['Id']?.toString()))
              .map((t) => t['Name']?.toString() ?? t['Nm']?.toString() ?? '')
              .where((t) => t.isNotEmpty)
              .toList();
        }
        
        // Update toggles dari Room
        if (room['IsMuteBot'] != null) _muteAIAgent = room['IsMuteBot'].toString() == 'true' || room['IsMuteBot'].toString() == '1';
        if (room['IsNeedReply'] != null) _needReply = room['IsNeedReply'].toString() == 'true' || room['IsNeedReply'].toString() == '1';
        
        final blockVal = room['IsBlock'] ?? room['CtIsBlock'];
        if (blockVal != null) _isBlocked = blockVal.toString() == 'true' || blockVal.toString() == '1';

        // Extract Agent info from RoomAgents if available
        try {
          if (roomData['RoomAgents'] != null && roomData['RoomAgents'] is List && (roomData['RoomAgents'] as List).isNotEmpty) {
            final firstAgent = (roomData['RoomAgents'] as List)[0];
            _agentEmail = firstAgent['UserEmail']?.toString() ?? '';
            final serverAgentName = firstAgent['DisplayName']?.toString() ?? '';
            if (serverAgentName.isNotEmpty) {
              _currentAgentName = serverAgentName;
            }
          }
          // Extract Account name from Account data
          if (roomData['Account'] != null && roomData['Account'] is Map) {
            final accountName = roomData['Account']['Name']?.toString() ?? '';
            if (accountName.isNotEmpty) {
              _currentAccount = accountName;
            }
          }
          // Extract Contact location data (Country, State, City)
          final contact = roomData['ContactReal'] ?? roomData['Contact'] ?? roomData['Room'] ?? roomData;
          debugPrint('ContactInfo: Trying contact source, type=${contact.runtimeType}');
          if (contact is Map) {
            final country = contact['Country']?.toString() ?? contact['Cntry']?.toString() ?? '';
            final state = contact['State']?.toString() ?? contact['Stt']?.toString() ?? contact['Province']?.toString() ?? '';
            final city = contact['City']?.toString() ?? contact['Cty']?.toString() ?? '';
            debugPrint('ContactInfo: Parsed => Country="$country", State="$state", City="$city"');
            if (country.isNotEmpty) _contactCountry = country;
            if (state.isNotEmpty) _contactState = state;
            if (city.isNotEmpty) _contactCity = city;
            
            final photo = contact['Photo']?.toString() ?? room['CtImg']?.toString() ?? room['LinkImg']?.toString() ?? '';
            if (photo.isNotEmpty) {
              if (photo.startsWith('http')) {
                _currentAvatarUrl = photo;
              } else {
                _currentAvatarUrl = 'https://id.nobox.ai/upload/$photo';
              }
            }
          }
          
          // Fallback: gunakan data lokasi lokal (optimistic save) jika server tidak punya/gagal update data
          final localLocation = chatProvider.getSavedContactLocation(widget.chat.id);
          if (localLocation != null) {
            if (_contactCountry.isEmpty && localLocation['Country'] != null) {
              _contactCountry = localLocation['Country']!;
            }
            if (_contactState.isEmpty && localLocation['State'] != null) {
              _contactState = localLocation['State']!;  
            }
            if (_contactCity.isEmpty && localLocation['City'] != null) {
              _contactCity = localLocation['City']!;
            }
          }
          
        } catch (e) {
          debugPrint('ContactInfo: Error extracting data: $e');
        }
      });
    }
  }

  void _showAccountPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F2C34) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final accounts = ['WhatsApp Business', 'Instagram', 'Facebook Messenger', 'Telegram'];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Pilih Akun', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                )),
              ),
              ...accounts.map((account) => ListTile(
                title: Text(account, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                trailing: _currentAccount == account ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() => _currentAccount = account);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Account changed to $account')),
                  );
                },
              )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _toggleSetting(String name, bool currentValue, ValueChanged<bool> onSaved) async {
    // Show a quick loading snacbkar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updating $name...'), duration: const Duration(milliseconds: 500)),
    );
    
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final newValue = !currentValue;
    
    bool isSuccess = false;
    if (name == 'Need Reply') {
      isSuccess = await chatProvider.toggleNeedReply(widget.chat.id, newValue);
    } else if (name == 'Mute AI Agent') {
      isSuccess = await chatProvider.toggleAiAgent(widget.chat.id, newValue);
    }
    
    if (isSuccess) {
      onSaved(newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name is now ${newValue ? 'ON' : 'OFF'}'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update $name: ${chatProvider.error}')),
        );
      }
    }
  }

  void _showAddFunnelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AddFunnelDialog(
          roomId: widget.chat.id,
          initialFunnel: _currentFunnel,
          onSave: (String funnelName, String funnelId) {
            if (mounted) {
              setState(() {
                _currentFunnel = funnelName;
              });
            }
          },
        );
      },
    );
  }

  void _dismissFunnelOverlay({bool updateState = true}) {
    try {
      if (_funnelOverlayEntry != null && _funnelOverlayEntry!.mounted) {
        _funnelOverlayEntry?.remove();
      }
    } catch (e) {
      debugPrint('Error removing funnel overlay: $e');
    }
    _funnelOverlayEntry = null;
    if (updateState && mounted) setState(() {});
  }

  void _showFunnelOverlay() async {
    // If overlay is already showing, dismiss it
    if (_funnelOverlayEntry != null) {
      _dismissFunnelOverlay();
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Load funnels if not cached
    if (_cachedFunnelItems.isEmpty) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final funnelData = await chatProvider.getFunnels();
      if (!mounted) return;
      if (funnelData != null) {
        _cachedFunnelItems = funnelData.map((f) {
          final name = f['Name']?.toString() ?? f['Nm']?.toString() ?? '';
          final id = f['Id']?.toString() ?? '';
          return {'name': name, 'id': id};
        }).where((f) => f['name']!.isNotEmpty).toList();
      }
    }

    if (_cachedFunnelItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada funnel tersedia')),
      );
      return;
    }

    // Get position of the funnel row
    final renderBox = _funnelRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _funnelOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            // Tap anywhere to dismiss
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismissFunnelOverlay,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            // The dropdown menu — connected directly below the funnel container
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height,
              width: size.width,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade300, width: 1),
                    right: BorderSide(color: Colors.grey.shade300, width: 1),
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _cachedFunnelItems.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (_, index) {
                        final funnel = _cachedFunnelItems[index];
                        final isSelected = _currentFunnel == funnel['name'];
                        return InkWell(
                          onTap: () async {
                            _dismissFunnelOverlay();
                            final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                            final success = await chatProvider.updateContactFunnel(
                              widget.chat.id, funnel['id']!, funnelName: funnel['name']!,
                            );
                            if (success && mounted) {
                              setState(() => _currentFunnel = funnel['name']!);
                            }
                          },
                          child: Container(
                            color: isSelected
                                ? (isDark ? Colors.blue.shade900.withOpacity(0.3) : const Color(0xFFE8F4FD))
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    funnel['name']!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isSelected
                                          ? Colors.blue
                                          : (isDark ? Colors.white : Colors.black87),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check, size: 20, color: Colors.blue),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_funnelOverlayEntry!);
    setState(() {}); // Rebuild container to flatten bottom corners
  }

  void _showFunnelList() {
    _showFunnelOverlay();
  }

  void _showRemoveFunnelConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.filter_alt_off, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 16),
                Text('Hapus Funnel', style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                )),
              ],
            ),
            const SizedBox(height: 20),
            Text('Are you sure you want to remove the funnel from this contact?', style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            )),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    _dismissFunnelOverlay();
                    
                    // Call API to remove funnel
                    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                    final success = await chatProvider.updateContactFunnel(widget.chat.id, "");
                    if (success && mounted) {
                      setState(() => _currentFunnel = '');
                    }
                  },
                  child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _convertNamesToIds(List<String> tagNames) {
    return tagNames.map((name) {
      final found = _availableTagsFromServer.firstWhere(
        (t) => (t['Name']?.toString() ?? t['Nm']?.toString() ?? '') == name,
        orElse: () => <String, dynamic>{},
      );
      if (found.isNotEmpty) {
        return found['Id']?.toString() ?? name;
      }
      return name;
    }).toList();
  }

  void _showRemoveTagConfirmation(String tag) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.label_off, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 16),
                Text('Hapus Tag', style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                )),
              ],
            ),
            const SizedBox(height: 20),
            Text('Are you sure you want to remove the tag "$tag"?', style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            )),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    
                    final newTagsList = List<String>.from(_currentTags)..remove(tag);
                    final tagIdsList = _convertNamesToIds(newTagsList);
                    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                    final success = await chatProvider.updateContactTags(widget.chat.id, tagIdsList, tagNames: newTagsList);
                    if (success && mounted) {
                      setState(() => _currentTags.remove(tag));
                    }
                  },
                  child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog() {
    final TextEditingController tagController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tambah Tag',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 18),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.blue, size: 24),
              ),
            ],
          ),
          content: TextField(
            controller: tagController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Enter tag name...',
              hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            autofocus: true,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      final newTag = tagController.text.trim();
                      if (newTag.isNotEmpty && !_currentTags.contains(newTag)) {
                        final newTagsList = List<String>.from(_currentTags)..add(newTag);
                        final tagIdsList = _convertNamesToIds(newTagsList);
                        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                        final success = await chatProvider.updateContactTags(widget.chat.id, tagIdsList, tagNames: newTagsList);
                        if (success) {
                          setState(() => _currentTags = newTagsList);
                        } else {
                           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add tag')));
                        }
                      }
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showMessageTagsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => TagSelectionDialog(
        roomId: widget.chat.id,
        initialSelectedTags: _currentTags,
        onSave: (List<String> updatedTags) {
          if (mounted) {
            setState(() {
              _currentTags = updatedTags;
            });
            final tagIdsList = _convertNamesToIds(updatedTags);
            Provider.of<ChatProvider>(context, listen: false)
                .updateLocalContactTags(widget.chat.id, tagIdsList, updatedTags);
          }
        },
      ),
    );
  }

  void _showEditNoteDialog() {
    final TextEditingController noteController = TextEditingController(text: _currentNotes);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tambah Catatan',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 18),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.blue, size: 24),
              ),
            ],
          ),
          content: TextField(
            controller: noteController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Enter your note...',
              hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            autofocus: true,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      final newNotes = noteController.text.trim();
                      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                      final success = await chatProvider.updateContactNotes(widget.chat.id, newNotes);
                      if (success) {
                        setState(() => _currentNotes = newNotes);
                      } else {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save notes')));
                      }
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showCampaignDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // API data
    List<CampaignItem> campaigns = [];
    bool isLoadingData = true;
    String? loadError;
    
    String selectedCampaignName = _currentCampaign;
    int? selectedCampaignId;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            // Fetch campaigns
            if (isLoadingData && campaigns.isEmpty && loadError == null) {
              Future.microtask(() async {
                try {
                  final resp = await chatProvider.getCampaignsResponse();
                  setDialogState(() {
                    isLoadingData = false;
                    if (!resp.isError && resp.data != null) {
                      campaigns = resp.data!.map((e) => CampaignItem.fromJson(e)).toList();
                      // find matching ID if we already have a name
                      if (selectedCampaignName.isNotEmpty) {
                        try {
                          final match = campaigns.firstWhere((c) => c.name.toLowerCase() == selectedCampaignName.toLowerCase());
                          selectedCampaignId = int.tryParse(match.id);
                        } catch (_) {}
                      }
                    }
                  });
                } catch (e) {
                  setDialogState(() {
                    isLoadingData = false;
                    loadError = e.toString();
                  });
                }
              });
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.campaign, color: Colors.blue.shade600, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text('Select Campaign', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w600, fontSize: 18)),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.blue.shade600, size: 24),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Campaign', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  if (isLoadingData)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 50),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  else if (loadError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: $loadError', style: const TextStyle(color: Colors.red)),
                    )
                  else if (campaigns.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 50),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No campaigns available', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          hint: Text('--select campaign--', style: TextStyle(color: Colors.grey.shade500)),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                          value: selectedCampaignId,
                          dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                          items: campaigns.map((c) {
                            return DropdownMenuItem<int>(
                              value: int.tryParse(c.id),
                              child: Text(c.name, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() {
                              selectedCampaignId = newValue;
                              try {
                                final c = campaigns.firstWhere((c) => c.id == newValue.toString());
                                selectedCampaignName = c.name;
                              } catch (_) {}
                            });
                          },
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (selectedCampaignId != null && !isLoadingData) ? Colors.blue : Colors.grey.shade300,
                        foregroundColor: (selectedCampaignId != null && !isLoadingData) ? Colors.white : Colors.grey.shade500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: (selectedCampaignId == null || isLoadingData) ? null : () async {
                        final success = await chatProvider.updateCampaign(widget.chat.id, selectedCampaignId);
                        if (success) {
                          if (mounted) {
                            setState(() {
                              _currentCampaign = selectedCampaignName;
                            });
                          }
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update campaign')));
                        }
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDealDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String localPipeline = _currentPipeline;
    String localStage = _currentStage;
    String localDeal = _currentDeal;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isSaveEnabled = localPipeline.isNotEmpty && localStage.isNotEmpty && localDeal.isNotEmpty;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.handshake, color: Colors.blue.shade600, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text('Select Deal', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w600, fontSize: 18)),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.blue.shade600, size: 24),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pipeline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text('--select--', style: TextStyle(color: Colors.grey.shade500)),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                          value: localPipeline.isEmpty ? null : localPipeline,
                          dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                          items: ['Sales', 'Marketing'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() {
                              localPipeline = newValue!;
                              localStage = '';
                              localDeal = '';
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Stage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text('--select pipeline first--', style: TextStyle(color: Colors.grey.shade500)),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                          value: localStage.isEmpty ? null : localStage,
                          dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                          items: localPipeline.isEmpty ? [] : ['Stage 1', 'Stage 2'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() {
                              localStage = newValue!;
                              localDeal = '';
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Deal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text('--select pipeline & stage first--', style: TextStyle(color: Colors.grey.shade500)),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                          value: localDeal.isEmpty ? null : localDeal,
                          dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                          items: localStage.isEmpty ? [] : ['Deal A', 'Deal B'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() => localDeal = newValue!);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSaveEnabled ? Colors.blue : Colors.grey.shade300,
                        foregroundColor: isSaveEnabled ? Colors.white : Colors.grey.shade500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: isSaveEnabled ? () async {
                        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                        final success = await chatProvider.updateContactDeal(widget.chat.id, localPipeline, localStage, localDeal);
                        if (success) {
                          setState(() {
                            _currentPipeline = localPipeline;
                            _currentStage = localStage;
                            _currentDeal = localDeal;
                          });
                        } else {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save deal')));
                        }
                        if (mounted) Navigator.pop(context);
                      } : null,
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFormTemplateDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Fetch form templates and form results from server
    final templatesData = await chatProvider.getFormTemplates();
    final resultsData = await chatProvider.getFormResults();

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    // Parse templates into {id, name} maps
    final templates = <Map<String, String>>[];
    if (templatesData != null) {
      for (final t in templatesData) {
        final name = t['Name']?.toString() ?? t['Nm']?.toString() ?? t['Title']?.toString() ?? '';
        final id = t['Id']?.toString() ?? '';
        if (name.isNotEmpty && id.isNotEmpty) {
          templates.add({'name': name, 'id': id});
        }
      }
    }

    // Parse results into {id, name} maps
    final results = <Map<String, String>>[];
    if (resultsData != null) {
      for (final r in resultsData) {
        final name = r['Name']?.toString() ?? r['Nm']?.toString() ?? r['Title']?.toString() ?? '';
        final id = r['Id']?.toString() ?? '';
        if (name.isNotEmpty && id.isNotEmpty) {
          results.add({'name': name, 'id': id});
        }
      }
    }

    if (templates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada form template tersedia dari server')),
        );
      }
      return;
    }

    String selectedTemplateId = '';
    String selectedTemplateName = _currentFormTemplate;
    String selectedResultId = '';
    String selectedResultName = _currentFormResult;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isSaveEnabled = selectedTemplateId.isNotEmpty;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.description, color: Colors.blue.shade600, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text('Form Template', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w600, fontSize: 18)),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: Colors.blue.shade600, size: 24),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Form Template', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text('--select--', style: TextStyle(color: Colors.grey.shade500)),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                          value: selectedTemplateId.isEmpty ? null : selectedTemplateId,
                          dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                          items: templates.map((t) {
                            return DropdownMenuItem<String>(
                              value: t['id']!,
                              child: Text(t['name']!, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() {
                              selectedTemplateId = newValue!;
                              selectedTemplateName = templates.firstWhere((t) => t['id'] == newValue)['name'] ?? '';
                              selectedResultId = '';
                              selectedResultName = '';
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Form Result', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text(selectedTemplateId.isEmpty ? '--select template first--' : '--select--', style: TextStyle(color: Colors.grey.shade500)),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
                          value: selectedResultId.isEmpty ? null : selectedResultId,
                          dropdownColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                          items: selectedTemplateId.isEmpty ? [] : results.map((r) {
                            return DropdownMenuItem<String>(
                              value: r['id']!,
                              child: Text(r['name']!, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() {
                              selectedResultId = newValue!;
                              selectedResultName = results.firstWhere((r) => r['id'] == newValue)['name'] ?? '';
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSaveEnabled ? Colors.blue : Colors.grey.shade300,
                        foregroundColor: isSaveEnabled ? Colors.white : Colors.grey.shade500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: isSaveEnabled ? () async {
                        final formTemplateId = int.tryParse(selectedTemplateId);
                        final formResultId = selectedResultId.isNotEmpty ? int.tryParse(selectedResultId) : null;
                        final success = await chatProvider.updateFormTemplate(
                          widget.chat.id, formTemplateId, formResultId: formResultId,
                        );
                        if (success) {
                          setState(() {
                            _currentFormTemplate = selectedTemplateName;
                            _currentFormResult = selectedResultName;
                          });
                        } else {
                          if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed to save form template')));
                        }
                        if (mounted) Navigator.pop(context);
                      } : null,
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chat = widget.chat;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Contact Detail',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Avatar + Name ──
            Container(
              color: isDark ? const Color(0xFF1F2C34) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: _currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty
                        ? NetworkImage(_currentAvatarUrl!)
                        : null,
                    child: (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty)
                        ? Icon(Icons.person, color: Colors.grey.shade600, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      chat.sender,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Conversation History ──
            _buildListTile(
              isDark: isDark,
              title: 'Conversation History',
              trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
              onTap: () {
                // Read ctId from chatProvider's room matching the current room ID
                final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                final allChats = chatProvider.chats;
                String ctId = chat.contactId; // fallback
                for (final room in allChats) {
                  if (room.id == chat.id) {
                    ctId = room.contactId;
                    break;
                  }
                }
                debugPrint('ConversationHistory: navigating with ctId=$ctId for roomId=${chat.id}');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConversationHistoryPage(
                      contactId: ctId,
                      contactName: chat.sender,
                      contactImage: _currentAvatarUrl ?? chat.avatarUrl,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // ── Contact Section ──
            _buildSectionContainer(
              isDark: isDark,
              children: [
                _buildSectionHeader(
                  isDark: isDark,
                  title: 'Contact',
                  actions: [
                    IconButton(
                      icon: Icon(
                        Icons.block,
                        size: 20, 
                        color: _isBlocked ? Colors.green : Colors.red,
                      ),
                      onPressed: () {
                        _showBlockDialog(context, isDark, chat.sender);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditContactPage(chat: chat),
                          ),
                        );
                        // Refresh data setelah kembali dari Edit Contact
                        _loadDetailRoom();
                      },
                    ),
                  ],
                ),
                _buildKeyValueRow(isDark: isDark, label: 'Name', value: chat.sender),
                if (_contactCountry.isNotEmpty)
                  _buildKeyValueRow(isDark: isDark, label: 'Country', value: _contactCountry, valueColor: isDark ? Colors.white : Colors.black),
                if (_contactState.isNotEmpty)
                  _buildKeyValueRow(isDark: isDark, label: 'State', value: _contactState, valueColor: isDark ? Colors.white : Colors.black),
                if (_contactCity.isNotEmpty)
                  _buildKeyValueRow(isDark: isDark, label: 'City', value: _contactCity, valueColor: isDark ? Colors.white : Colors.black),
              ],
            ),

            const SizedBox(height: 8),

            // ── Conversation Section ──
            _buildSectionContainer(
              isDark: isDark,
              children: [
                _buildSectionHeader(isDark: isDark, title: 'Conversation'),
                InkWell(
                  onTap: _showAccountPicker,
                  child: _buildStackedValueRow(
                    isDark: isDark,
                    label: 'Account',
                    value: _currentAccount,
                    valueColor: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSwitchRow(
                  isDark: isDark,
                  label: 'Need Reply',
                  value: _needReply,
                  onChanged: (val) => _toggleSetting('Need Reply', _needReply, (newVal) => setState(() => _needReply = newVal)),
                ),
                _buildSwitchRow(
                  isDark: isDark,
                  label: 'Mute AI Agent',
                  value: _muteAIAgent,
                  onChanged: (val) => _toggleSetting('Mute AI Agent', _muteAIAgent, (newVal) => setState(() => _muteAIAgent = newVal)),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Funnel Section ──
            _buildSectionContainer(
              isDark: isDark,
              children: [
                InkWell(
                  onTap: _showFunnelList,
                  child: _buildSectionHeader(
                    isDark: isDark,
                    title: 'Funnel',
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.add, size: 22, color: Colors.lightBlue),
                        onPressed: _showAddFunnelDialog,
                      ),
                    ],
                  ),
                ),
                if (_currentFunnel.isNotEmpty)
                  Padding(
                    key: _funnelRowKey,
                    padding: EdgeInsets.fromLTRB(16, 0, 16, _funnelOverlayEntry != null ? 0 : 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.shade900.withOpacity(0.15) : Colors.blue.shade50.withOpacity(0.4),
                        borderRadius: _funnelOverlayEntry != null
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                topRight: Radius.circular(10),
                              )
                            : BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _currentFunnel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showRemoveFunnelConfirmation,
                            child: Icon(Icons.close, size: 20, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _showFunnelOverlay,
                            child: Icon(Icons.arrow_drop_down, size: 24, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    key: _funnelRowKey,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: InkWell(
                      onTap: _showFunnelOverlay,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300, width: 1),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'No funnel assigned',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, size: 24, color: Colors.grey.shade500),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Message Tags Section ──
            _buildSectionContainer(
              isDark: isDark,
              children: [
                InkWell(
                  onTap: _showMessageTagsDialog,
                  child: _buildSectionHeader(
                    isDark: isDark,
                    title: 'Message Tags',
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 22, color: Colors.lightBlue),
                        onPressed: _showAddTagDialog,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 22, color: Colors.lightBlue),
                        onPressed: _showMessageTagsDialog,
                      ),
                    ],
                  ),
                ),
                if (_currentTags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _currentTags.map((tag) {
                        return Chip(
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.blue.shade50,
                          side: BorderSide.none,
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _showRemoveTagConfirmation(tag),
                        );
                      }).toList(),
                    ),
                  )
                else
                  InkWell(
                    onTap: _showMessageTagsDialog,
                    child: _buildPlaceholderRow(isDark: isDark, text: 'No tags added yet', showIcon: false),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Notes Section ──
            _buildSectionContainer(
              isDark: isDark,
              children: [
                InkWell(
                  onTap: _showEditNoteDialog,
                  child: _buildSectionHeader(
                    isDark: isDark,
                    title: 'Notes',
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.add, size: 22, color: Colors.lightBlue),
                        onPressed: _showEditNoteDialog,
                      ),
                    ],
                  ),
                ),
                if (_currentNotes.isNotEmpty)
                  InkWell(
                    onTap: _showEditNoteDialog,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        _currentNotes,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: _showEditNoteDialog,
                    child: _buildPlaceholderRow(isDark: isDark, text: 'No notes added yet', showIcon: false),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Campaign Section ──
            _buildSectionContainer(
              isDark: isDark,
              children: [
                InkWell(
                  onTap: _showCampaignDialog,
                  child: _buildSectionHeader(
                    isDark: isDark,
                    title: 'Campaign',
                    actions: [
                      IconButton(
                        icon: Icon(Icons.open_in_new, size: 20, color: Colors.blue.shade400),
                        onPressed: _showCampaignDialog,
                      ),
                    ],
                  ),
                ),
                if (_currentCampaign.isNotEmpty)
                  InkWell(
                    onTap: _showCampaignDialog,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        _currentCampaign,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: _showCampaignDialog,
                    child: _buildPlaceholderValue(isDark: isDark, text: 'Not Set'),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Deal Section ──
            _buildSectionContainer(
              isDark: isDark,
              children: [
                InkWell(
                  onTap: _showDealDialog,
                  child: _buildSectionHeader(
                    isDark: isDark,
                    title: 'Deal',
                    actions: [
                      IconButton(
                        icon: Icon(Icons.open_in_new, size: 20, color: Colors.blue.shade400),
                        onPressed: _showDealDialog,
                      ),
                    ],
                  ),
                ),
                if (_currentDeal.isNotEmpty)
                  InkWell(
                    onTap: _showDealDialog,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pipeline: $_currentPipeline',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Stage: $_currentStage',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentDeal,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: _showDealDialog,
                    child: _buildPlaceholderValue(isDark: isDark, text: 'Not Set'),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Form Template Section ──
            _buildSectionContainer(
              isDark: isDark,
              children: [
                InkWell(
                  onTap: _showFormTemplateDialog,
                  child: _buildSectionHeader(
                    isDark: isDark,
                    title: 'Form Template',
                    actions: [
                      IconButton(
                        icon: Icon(Icons.open_in_new, size: 20, color: Colors.blue.shade400),
                        onPressed: _showFormTemplateDialog,
                      ),
                    ],
                  ),
                ),
                if (_currentFormTemplate.isNotEmpty)
                  InkWell(
                    onTap: _showFormTemplateDialog,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        _currentFormTemplate,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: _showFormTemplateDialog,
                    child: _buildPlaceholderValue(isDark: isDark, text: 'Not Set'),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Form Result Section ──
            _buildSectionContainer(
              isDark: isDark,
              children: [
                InkWell(
                  onTap: _showFormTemplateDialog,
                  child: _buildSectionHeader(
                    isDark: isDark,
                    title: 'Form Result',
                  ),
                ),
                if (_currentFormResult.isNotEmpty)
                  InkWell(
                    onTap: _showFormTemplateDialog,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        _currentFormResult,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: _showFormTemplateDialog,
                    child: _buildPlaceholderValue(isDark: isDark, text: 'Not Set'),
                  ),
              ],
            ),

            const SizedBox(height: 8),


            // ── Human Agent Section ──
            _buildSectionContainer(
              isDark: isDark,
              children: [
                InkWell(
                  onTap: _showAgentDialog,
                  child: _buildSectionHeader(
                    isDark: isDark,
                    title: 'Human Agent',
                  ),
                ),
                if (_currentAgentName.isNotEmpty)
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      onTap: _showAgentDialog,
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey.shade200,
                        child: Icon(Icons.person, color: Colors.grey.shade500, size: 24),
                      ),
                      title: Text(
                        _currentAgentName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: _agentEmail.isNotEmpty
                          ? Text(
                              _agentEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            )
                          : null,
                      trailing: InkWell(
                        onTap: () async {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removing agent...')));
                          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                          final success = await chatProvider.removeAgent(widget.chat.id);
                          if (success) {
                            setState(() {
                              _currentAgentName = '';
                              _agentEmail = '';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agent removed')));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to remove agent')));
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(Icons.close, size: 20, color: Colors.red.shade400),
                        ),
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: _showAgentDialog,
                    child: _buildPlaceholderValue(isDark: isDark, text: 'Not Set'),
                  ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  HELPER WIDGETS
  // ─────────────────────────────────────────────

  Widget _buildListTile({
    required bool isDark,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      color: isDark ? const Color(0xFF1F2C34) : Colors.white,
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildSectionContainer({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF1F2C34) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSectionHeader({
    required bool isDark,
    required String title,
    List<Widget>? actions,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          if (actions != null) ...actions,
        ],
      ),
    );
  }

  Widget _buildKeyValueRow({
    required bool isDark,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? (isDark ? Colors.white : Colors.blue),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedValueRow({
    required bool isDark,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? Colors.blue,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required bool isDark,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderRow({
    required bool isDark,
    required String text,
    bool showIcon = true,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade400,
              ),
            ),
          ),
          if (showIcon) const Icon(Icons.add, size: 20, color: Colors.lightBlue),
        ],
      ),
    );
  }

  Widget _buildPlaceholderValue({
    required bool isDark,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey[500] : Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  void _showBlockDialog(BuildContext context, bool isDark, String contactName) {
    final isCurrentlyBlocked = _isBlocked;
    final actionName = isCurrentlyBlocked ? 'Unblock' : 'Block';
    final actionDesc = isCurrentlyBlocked 
        ? 'Are you sure you want to unblock this contact? You will receive messages from them.'
        : 'Are you sure you want to block this contact? You will not receive messages from them.';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isCurrentlyBlocked ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.block, 
                  color: isCurrentlyBlocked ? Colors.green.shade600 : Colors.red.shade600, 
                  size: 24
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$actionName Contact',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            actionDesc,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                backgroundColor: isCurrentlyBlocked ? Colors.green.shade600 : Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                Navigator.pop(context);
                
                // Show loading indicator
                showDialog(
                  context: this.context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );
                
                final chatProvider = Provider.of<ChatProvider>(this.context, listen: false);
                final newBlockedState = !isCurrentlyBlocked;
                final success = await chatProvider.toggleBlockContact(widget.chat.id, widget.chat.contactId, newBlockedState);
                
                if (!mounted) return;
                Navigator.pop(this.context); // hide loading
                
                if (success) {
                  // FIX Bug #4: Update local state so UI is reactive
                  setState(() {
                    _isBlocked = newBlockedState;
                  });
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(isCurrentlyBlocked ? 'unblock sukses' : 'block sukses'),
                      backgroundColor: Colors.green.withOpacity(0.8),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to $actionName contact'),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text(actionName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ],
        );
      },
    );
  }

  void _showAgentDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Show a loading indicator first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final agents = await chatProvider.getAgents();
    
    if (!mounted) return;
    Navigator.pop(context); // hide loading

    if (agents == null || agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No agents found or failed to load')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select Agent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.close, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: agents.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final agent = agents[index];
                      final agentName = agent['DisplayName']?.toString() ?? agent['Name']?.toString() ?? 'Unknown Agent';
                      final agentUserId = agent['UserId']?.toString() ?? agent['Id']?.toString() ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.person, size: 18, color: Colors.blue),
                        ),
                        title: Text(agentName, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                        subtitle: Text(agent['Username']?.toString() ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        onTap: () async {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Assigning to $agentName...')));
                          
                          final success = await chatProvider.assignAgent(widget.chat.id, agentUserId, agentName);
                          if (success) {
                            if (mounted) {
                              setState(() {
                                _currentAgentName = agentName;
                                _agentEmail = agent['Email']?.toString() ?? agent['Username']?.toString() ?? '';
                              });
                            }
                            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Successfully assigned to $agentName')));
                          } else {
                            ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed to assign agent')));
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
