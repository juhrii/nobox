import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/app_config.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/media_service.dart';
import '../../widgets/searchable_dropdown.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  // Form Keys for Auto-Scroll Validation
  final GlobalKey _timezoneKey = GlobalKey();
  final GlobalKey _countryKey = GlobalKey();
  final GlobalKey _stateKey = GlobalKey();
  final GlobalKey _cityKey = GlobalKey();

  Map<String, dynamic> _jwtPayload = {};
  bool _isLoadingProfile = true;
  Map<String, dynamic>? _userProfile;

  // User Image Upload
  File? _selectedImage;
  bool _isUploadingImage = false;

  // Time Preview
  Timer? _timePreviewTimer;

  // Master Data Lists
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _timezones = [];

  @override
  void initState() {
    super.initState();
    _decodeToken();
    _loadMasterData();
    _timePreviewTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timePreviewTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    _countries = await _fetchMasterList(AppConfig.countryListEndpoint);
    _timezones = await _fetchMasterList(AppConfig.timezoneListEndpoint);
    if (mounted) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _fetchMasterList(
    String endpoint, {
    dynamic criteria,
  }) async {
    try {
      final response = await ApiClient().dio.post(
        endpoint,
        data: {
          "Sort": ["Name"],
          "ColumnSelection": 1,
          "IncludeColumns": ["Name", "Id"],
          "Criteria": criteria,
          "ExcludeTotalCount": true,
          "Skip": 0,
          "Take": 1000, // Tarik data sebanyak mungkin
        },
      );
      if (response.data != null && response.data['Entities'] != null) {
        return List<Map<String, dynamic>>.from(response.data['Entities']);
      }
    } catch (e) {
      debugPrint('Error fetching master data from $endpoint: $e');
    }
    return [];
  }

  void _decodeToken() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().token;
      if (token != null && token.isNotEmpty) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = parts[1];
            String normalized = base64Url.normalize(payload);
            String decoded = utf8.decode(base64Url.decode(normalized));
            setState(() {
              _jwtPayload = jsonDecode(decoded);
            });

            // Extrak User ID untuk panggil API
            final String? userIdStr = getJwtValue([
              'nameidentifier',
              'nameid',
              'id',
              'uid',
              'sub',
              'UserId',
            ]);
            if (userIdStr != null) {
              _fetchUserProfile(int.tryParse(userIdStr.toString()) ?? 0);
            } else {
              setState(() => _isLoadingProfile = false);
            }
          }
        } catch (e) {
          debugPrint('Error decoding JWT token: $e');
          setState(() => _isLoadingProfile = false);
        }
      } else {
        setState(() => _isLoadingProfile = false);
      }
    });
  }

  Future<void> _fetchUserProfile(int userId) async {
    if (userId == 0) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }
    try {
      final response = await ApiClient().post(
        AppConfig.retrieveUserEndpoint,
        data: {"EntityId": userId},
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['Entity'] != null) {
          debugPrint(
            '>>> FETCHED PROFILE: FormatDate=${data['Entity']['FormatDate']}, FormatTime=${data['Entity']['FormatTime']}, FormatNumber=${data['Entity']['FormatNumber']}',
          );
          if (mounted) {
            setState(() {
              _userProfile = data['Entity'];
            });
            await _loadDependentAddressData();
            if (mounted) setState(() => _isLoadingProfile = false);
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
    if (mounted) setState(() => _isLoadingProfile = false);
  }

  Future<void> _loadDependentAddressData() async {
    if (_userProfile == null) return;

    final String? ctryId = _userProfile!['CtryId']?.toString();
    if (ctryId != null && ctryId.isNotEmpty) {
      final newStates = await _fetchMasterList(
        AppConfig.stateListEndpoint,
        criteria: [
          ["CountryId"],
          "=",
          ctryId,
        ],
      );
      if (mounted) setState(() => _states = newStates);
    }

    final String? statesId = _userProfile!['StatesId']?.toString();
    if (statesId != null && statesId.isNotEmpty) {
      final newCities = await _fetchMasterList(
        AppConfig.cityListEndpoint,
        criteria: [
          ["StateId"],
          "=",
          statesId,
        ],
      );
      if (mounted) setState(() => _cities = newCities);
    }
  }

  String? getJwtValue(List<String> possibleKeys) {
    for (final pk in possibleKeys) {
      if (_jwtPayload.containsKey(pk)) return _jwtPayload[pk].toString();
    }
    for (final key in _jwtPayload.keys) {
      for (final pk in possibleKeys) {
        if (key.toLowerCase().endsWith('/$pk'.toLowerCase()) ||
            key.toLowerCase().endsWith('claims/$pk'.toLowerCase())) {
          return _jwtPayload[key].toString();
        }
      }
    }
    return null;
  }

  bool _validateForm() {
    if (_userProfile == null) return true;

    final entity = _userProfile!;
    if ((entity['Timezone']?.toString() ?? '').isEmpty) {
      _showTopNotification('Timezone is required', key: _timezoneKey);
      return false;
    }
    if ((entity['Ctry']?.toString() ?? '').isEmpty) {
      _showTopNotification('Country is required', key: _countryKey);
      return false;
    }

    // Validasi Separators
    if (entity['FormatNumber'] != null) {
      try {
        final formatNum = jsonDecode(entity['FormatNumber']);
        final aDec = formatNum['aDec']?.toString() ?? ',';
        final aSep = formatNum['aSep']?.toString() ?? '.';

        if (aDec == aSep && aDec.isNotEmpty) {
          _showTopNotification(
            'Decimal Separator and Thousand Separator cannot be identical.',
          );
          return false;
        }
      } catch (e) {}
    }

    if ((entity['States']?.toString() ?? '').isEmpty) {
      _showTopNotification('State is required', key: _stateKey);
      return false;
    }
    if ((entity['City']?.toString() ?? '').isEmpty) {
      _showTopNotification('City is required', key: _cityKey);
      return false;
    }
    return true;
  }

  void _showTopNotification(
    String message, {
    GlobalKey? key,
    bool isError = true,
    int durationSeconds = 3,
  }) {
    final overlay = Overlay.of(context);
    bool isRemoved = false;
    late OverlayEntry entry;

    void removeEntry() {
      if (!isRemoved) {
        isRemoved = true;
        entry.remove();
      }
    }

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isError ? Colors.red.shade500 : Colors.green.shade500,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: removeEntry,
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(Duration(seconds: durationSeconds), () {
      if (mounted) removeEntry();
    });

    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
      );
    }
  }

  // ── User Image Upload ──
  Future<void> _pickAndUploadImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E293B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: Colors.blue.shade400),
                  title: Text(
                    'Camera',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: Colors.blue.shade400),
                  title: Text(
                    'Gallery',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      setState(() {
        _selectedImage = file;
        _isUploadingImage = true;
      });

      // Gunakan TemporaryUpload (Multipart) agar diterima oleh Serenity Save Handler
      final fileName = pickedFile.name;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final uploadResponse = await ApiClient().post(
        'File/TemporaryUpload',
        data: formData,
      );

      String? serverFilename;
      if (uploadResponse.statusCode == 200) {
        final responseData = uploadResponse.data;
        if (responseData is Map) {
          if (responseData['TemporaryFile'] != null) {
            serverFilename = responseData['TemporaryFile'].toString();
          } else if (responseData['Data'] != null) {
            final raw = responseData['Data'];
            if (raw is Map && raw['TemporaryFile'] != null) {
              serverFilename = raw['TemporaryFile'].toString();
            }
          }
        }
      }

      if (serverFilename != null && mounted) {
        setState(() {
          _userProfile ??= {};
          _userProfile!['UserImage'] = serverFilename;
          _isUploadingImage = false;
        });
        _showTopNotification(
          'Image uploaded successfully!',
          isError: false,
        );
      } else if (mounted) {
        setState(() => _isUploadingImage = false);
        _showTopNotification('Failed to upload image.');
      }
    } catch (e) {
      debugPrint('Error picking/uploading image: $e');
      if (mounted) {
        setState(() => _isUploadingImage = false);
        _showTopNotification('Error: $e');
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _userProfile ??= {};
      _userProfile!['UserImage'] = null;
    });
  }

  Future<void> _saveProfile() async {
    if (_userProfile == null) return;
    if (!_validateForm()) return;
    setState(() => _isLoadingProfile = true);
    try {
      final entity = Map<String, dynamic>.from(_userProfile!);

      debugPrint('>>> SAVING PROFILE: FormatNumber=${entity['FormatNumber']}');

      // Hapus field read-only bawaan Serenity agar tidak memicu error 400 "field is read only"
      entity.remove('UpdateDate');
      entity.remove('UpdateUserId');
      entity.remove('InsertDate');
      entity.remove('InsertUserId');

      // Debugging formats before save
      debugPrint(
        '>>> SAVING PROFILE: FormatDate=${entity['FormatDate']}, FormatTime=${entity['FormatTime']}',
      );

      // Resolve IDs from Names for Master Data
      String? ctryName = entity['Ctry'];
      if (ctryName != null && ctryName.isNotEmpty) {
        final found = _countries.firstWhere(
          (e) => e['Name'] == ctryName,
          orElse: () => <String, dynamic>{},
        );
        if (found['Id'] != null) entity['CtryId'] = found['Id'].toString();
      }

      String? stateName = entity['States'];
      if (stateName != null && stateName.isNotEmpty) {
        final found = _states.firstWhere(
          (e) => e['Name'] == stateName,
          orElse: () => <String, dynamic>{},
        );
        if (found['Id'] != null) entity['StatesId'] = found['Id'].toString();
      } else {
        entity.remove('StatesId');
      }

      String? cityName = entity['City'];
      if (cityName != null && cityName.isNotEmpty) {
        final found = _cities.firstWhere(
          (e) => e['Name'] == cityName,
          orElse: () => <String, dynamic>{},
        );
        if (found['Id'] != null) entity['CityId'] = found['Id'].toString();
      } else {
        entity.remove('CityId');
      }

      String? tzName = entity['Timezone']?.toString();
      if (tzName != null && tzName.isNotEmpty) {
        final found = _timezones.firstWhere(
          (e) => e['Name'] == tzName,
          orElse: () => <String, dynamic>{},
        );
        if (found['Id'] != null) {
          entity['Timezone'] = found['Id'].toString();
        } else if (int.tryParse(tzName) == null) {
          // Jika nilai ini adalah string (misal: "Asia/Jakarta") dan tidak ketemu ID-nya,
          // kita hapus (remove) dari payload agar server tidak crash saat parse ke Int32.
          entity.remove('Timezone');
        }
      }

      final payload = {
        "EntityId": entity['UserId'] ?? entity['Id'],
        "Entity": entity,
      };

      final response = await ApiClient().dio.post(
        'Services/Administration/User/Update',
        data: payload,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          _showTopNotification('Profile saved successfully!', isError: false);
        }
        await _fetchUserProfile(
          int.tryParse(entity['EntityId'].toString()) ?? 0,
        );
      } else {
        if (mounted) {
          _showTopNotification(
            'Failed to save profile. Status: ${response.statusCode}',
            durationSeconds: 5,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (e is DioException && e.response != null) {
          errorMsg =
              'Status: ${e.response?.statusCode}\nBody: ${e.response?.data}';
        }
        _showTopNotification(
          'Error saving profile:\n$errorMsg',
          durationSeconds: 8,
        );
      }
    }
    if (mounted) setState(() => _isLoadingProfile = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final labelColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final dividerColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    final String email =
        _userProfile?['Email'] ??
        getJwtValue(['emailaddress', 'email', 'name', 'unique_name']) ??
        auth.currentUser ??
        '';
    final String orgName =
        _userProfile?['TnNm'] ??
        getJwtValue([
          'Tenant',
          'TenantName',
          'TenantId',
          'Organization',
          'org',
          'company',
        ]) ??
        'Nobox Chat';
    final String role = getJwtValue(['role', 'Role', 'roles']) ?? '';
    final String displayName =
        _userProfile?['DisplayName'] ??
        getJwtValue(['givenname', 'name', 'displayname']) ??
        '';

    final String mobilePhone = _userProfile?['MobilePhoneNumber'] ?? '';
    String timezone = _userProfile?['Timezone']?.toString() ?? 'Asia/Jakarta';

    // Server NoBox mereturn Timezone berupa ID (misal: "186"). Kita harus menerjemahkannya ke Nama ("Asia/Jakarta") untuk UI
    if (_timezones.isNotEmpty) {
      final tzItem = _timezones.firstWhere(
        (e) => e['Id'].toString() == timezone,
        orElse: () => <String, dynamic>{},
      );
      if (tzItem['Name'] != null) {
        timezone = tzItem['Name'].toString();
      }
    } else if (int.tryParse(timezone) != null) {
      // Jika master data belum selesai di-download, dan timezone masih berupa angka murni (ID),
      // kita tampilkan teks "Loading..." agar tidak kedap-kedip menampilkan angka "186".
      timezone = 'Loading...';
    }

    final String country = _userProfile?['Ctry'] ?? '';
    final String state = _userProfile?['States'] ?? '';
    final String city = _userProfile?['City'] ?? '';

    final String dateFormat = _userProfile?['FormatDate'] ?? 'DD-MM-YYYY';
    final String timeFormat = _userProfile?['FormatTime'] ?? 'HH:mm';

    String decimalSeparator = "Comma ','";
    String thousandSeparator = "Period '.'";
    String decimalPlaces = '0';
    String thousandGrouping = '3';
    String leadingZero = 'Allow';

    if (_userProfile?['FormatNumber'] != null) {
      try {
        final formatNum = jsonDecode(_userProfile!['FormatNumber']);
        decimalSeparator = formatNum['aDec']?.toString() ?? ',';
        thousandSeparator = formatNum['aSep']?.toString() ?? '.';
        decimalPlaces = formatNum['mDec']?.toString() ?? '0';
        thousandGrouping = formatNum['dGroup']?.toString() ?? '3';
        leadingZero = formatNum['lZero']?.toString() ?? 'allow';
        debugPrint(
          '>>> PARSED RAW SEPARATORS: dec="$decimalSeparator", thou="$thousandSeparator"',
        );
      } catch (e) {}
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'User Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? textColor : Colors.white,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? textColor : Colors.white,
        ),
        backgroundColor: isDark ? cardColor : Colors.blue,
        foregroundColor: isDark ? textColor : Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: dividerColor, height: 1),
        ),
      ),
      body: _isLoadingProfile
          ? Center(
              child: CircularProgressIndicator(color: Colors.blue.shade400),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Action Buttons
                    Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: _saveProfile,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue.shade400,
                                side: BorderSide(color: Colors.blue.shade400.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.all(12),
                                minimumSize: const Size(0, 0),
                              ),
                              child: const Icon(Icons.check, size: 20),
                            ),
                            const SizedBox(width: 12),
                            _buildActionButton(
                              icon: Icons.close,
                              label: 'Unsubscribe',
                              color: Colors.red.shade400,
                              onPressed: () {},
                            ),
                            const SizedBox(width: 12),
                            _buildActionButton(
                              icon: Icons.exit_to_app,
                              label: 'Exit from Tenant',
                              color: Colors.red.shade400,
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader(
                      'General Info',
                      textColor,
                      dividerColor,
                    ),
                    _buildGeneralForm(
                      cardColor,
                      textColor,
                      labelColor,
                      dividerColor,
                      email,
                      orgName,
                      displayName,
                      mobilePhone,
                      timezone,
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader('Address', textColor, dividerColor),
                    _buildAddressForm(
                      cardColor,
                      textColor,
                      labelColor,
                      dividerColor,
                      country,
                      state,
                      city,
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader('Date Format', textColor, dividerColor),
                    _buildDateFormatForm(
                      cardColor,
                      textColor,
                      labelColor,
                      dividerColor,
                      dateFormat,
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader('Time Format', textColor, dividerColor),
                    _buildTimeFormatForm(
                      cardColor,
                      textColor,
                      labelColor,
                      dividerColor,
                      timeFormat,
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      'Number Format',
                      textColor,
                      dividerColor,
                    ),
                    _buildNumberFormatForm(
                      cardColor,
                      textColor,
                      labelColor,
                      dividerColor,
                      decimalSeparator,
                      thousandSeparator,
                      decimalPlaces,
                      thousandGrouping,
                      leadingZero,
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      'Login History',
                      textColor,
                      dividerColor,
                    ),
                    _buildLoginHistoryTable(
                      cardColor,
                      textColor,
                      labelColor,
                      dividerColor,
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    Color textColor,
    Color dividerColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade400,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Container(height: 1, color: dividerColor)),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildGeneralForm(
    Color cardColor,
    Color textColor,
    Color labelColor,
    Color borderColor,
    String email,
    String tenant,
    String displayName,
    String mobilePhone,
    String timezone,
  ) {
    List<String> tzOptions = _timezones.isNotEmpty
        ? _timezones
              .map((e) => e['Name']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList()
        : [timezone, 'Asia/Jakarta', 'UTC', 'America/New_York'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          'Username',
          email,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          enabled: false,
        ),
        _buildTextField(
          'Display Name',
          displayName,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          isRequired: true,
        ),

        const SizedBox(height: 12),

        _buildTextField(
          'Email',
          email,
          cardColor,
          textColor,
          labelColor,
          borderColor,
        ),
        _buildTextField(
          'Mobile Phone Number',
          mobilePhone,
          cardColor,
          textColor,
          labelColor,
          borderColor,
        ),
        _buildDropdownField(
          'Timezone',
          timezone,
          tzOptions,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          isRequired: true,
          fieldKey: _timezoneKey,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _userProfile ??= {};
                _userProfile!['Timezone'] =
                    val; // sementara simpan nama agar UI terupdate
              });
            }
          },
        ),
        _buildTextField(
          'Tenant',
          tenant,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          enabled: false,
        ),

        // User Image Select
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Image',
                style: TextStyle(
                  color: labelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              _buildUserImageArea(cardColor, borderColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserImageArea(Color cardColor, Color borderColor) {
    final String? serverImage = _userProfile?['UserImage']?.toString();
    final bool hasLocalImage = _selectedImage != null;
    final bool hasServerImage = serverImage != null && serverImage.isNotEmpty;
    final bool hasImage = hasLocalImage || hasServerImage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
        color: cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Button Group (Select File | Trash)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickAndUploadImage,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.file_upload_outlined,
                              size: 18, color: Colors.blue.shade600),
                          const SizedBox(width: 6),
                          const Text(
                            'Select File',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 34, color: borderColor),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _removeImage,
                    borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Icon(Icons.delete_outline,
                          size: 18, color: Colors.red.shade400),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (_isUploadingImage || hasImage) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                color: Colors.transparent,
              ),
              child: _isUploadingImage
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Uploading...',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(16),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                InteractiveViewer(
                                  child: hasLocalImage
                                      ? Image.file(_selectedImage!)
                                      : Image.network(
                                          serverImage!.startsWith('http')
                                              ? serverImage
                                              : '${AppConfig.uploadUrl}$serverImage',
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.broken_image,
                                            size: 64,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.white),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: hasLocalImage
                          ? Image.file(
                              _selectedImage!,
                              fit: BoxFit.contain,
                            )
                          : Image.network(
                              serverImage!.startsWith('http')
                                  ? serverImage
                                  : '${AppConfig.uploadUrl}$serverImage',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressForm(
    Color cardColor,
    Color textColor,
    Color labelColor,
    Color borderColor,
    String country,
    String state,
    String city,
  ) {
    List<String> countryOptions = _countries.isNotEmpty
        ? _countries
              .map((e) => e['Name']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList()
        : [country, 'Indonesia', 'Malaysia', 'Singapore'];

    List<String> stateOptions = _states.isNotEmpty
        ? _states
              .map((e) => e['Name']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList()
        : (state.isNotEmpty ? [state] : []);

    List<String> cityOptions = _cities.isNotEmpty
        ? _cities
              .map((e) => e['Name']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList()
        : (city.isNotEmpty ? [city] : []);

    return Column(
      children: [
        _buildDropdownField(
          'Country',
          country,
          countryOptions,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          isRequired: true,
          fieldKey: _countryKey,
          onChanged: (val) async {
            if (val != null) {
              setState(() {
                _userProfile ??= {};
                _userProfile!['Ctry'] = val;
                _userProfile!['States'] = '';
                _userProfile!['City'] = '';
                _states = [];
                _cities = [];
              });

              final selected = _countries.firstWhere(
                (e) => e['Name'] == val,
                orElse: () => <String, dynamic>{},
              );
              if (selected['Id'] != null) {
                _userProfile!['CtryId'] = selected['Id'].toString();
                final newStates = await _fetchMasterList(
                  AppConfig.stateListEndpoint,
                  criteria: [
                    ["CountryId"],
                    "=",
                    selected['Id'].toString(),
                  ],
                );
                if (mounted) setState(() => _states = newStates);
              }
            }
          },
        ),
        _buildDropdownField(
          'State',
          state,
          stateOptions,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          isRequired: true,
          fieldKey: _stateKey,
          onChanged: (val) async {
            if (val != null) {
              setState(() {
                _userProfile ??= {};
                _userProfile!['States'] = val;
                _userProfile!['City'] = '';
                _cities = [];
              });

              final selected = _states.firstWhere(
                (e) => e['Name'] == val,
                orElse: () => <String, dynamic>{},
              );
              if (selected['Id'] != null) {
                _userProfile!['StatesId'] = selected['Id'].toString();
                final newCities = await _fetchMasterList(
                  AppConfig.cityListEndpoint,
                  criteria: [
                    ["StateId"],
                    "=",
                    selected['Id'].toString(),
                  ],
                );
                if (mounted) setState(() => _cities = newCities);
              }
            }
          },
        ),
        _buildDropdownField(
          'City',
          city,
          cityOptions,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          isRequired: true,
          fieldKey: _cityKey,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _userProfile ??= {};
                _userProfile!['City'] = val;
                final selected = _cities.firstWhere(
                  (e) => e['Name'] == val,
                  orElse: () => <String, dynamic>{},
                );
                if (selected['Id'] != null) {
                  _userProfile!['CityId'] = selected['Id'].toString();
                }
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildDateFormatForm(
    Color cardColor,
    Color textColor,
    Color labelColor,
    Color borderColor,
    String dateFormat,
  ) {
    final List<String> formats = [
      'DD/MM/YYYY',
      'DD-MM-YYYY',
      'DD/MMM/YYYY',
      'DD-MMM-YYYY',
      'dddd, MMMM D, YYYY',
      'MMMM D, YYYY',
    ];
    if (dateFormat.isNotEmpty && !formats.contains(dateFormat)) {
      formats.insert(0, dateFormat);
    }

    final currentFormat = dateFormat.isEmpty ? 'DD-MM-YYYY' : dateFormat;

    String getPreview(String format) {
      final now = DateTime.now();
      final d = now.day.toString().padLeft(2, '0');
      final dNoPad = now.day.toString();
      final m = now.month.toString().padLeft(2, '0');
      final y = now.year.toString();

      final monthsShort = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final monthsFull = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final daysFull = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];

      final mmm = monthsShort[now.month - 1];
      final mmmm = monthsFull[now.month - 1];
      final dddd = daysFull[now.weekday - 1];

      if (format == 'DD/MM/YYYY') return '$d/$m/$y';
      if (format == 'DD-MM-YYYY') return '$d-$m-$y';
      if (format == 'DD/MMM/YYYY') return '$d/$mmm/$y';
      if (format == 'DD-MMM-YYYY') return '$d-$mmm-$y';
      if (format == 'dddd, MMMM D, YYYY') return '$dddd, $mmmm $dNoPad, $y';
      if (format == 'MMMM D, YYYY') return '$mmmm $dNoPad, $y';

      return '$d/$m/$y';
    }

    final dateExamples = formats.map((f) => getPreview(f)).toList();
    final currentExample = getPreview(currentFormat);

    return Column(
      children: [
        _buildDropdownField(
          'Date',
          currentExample,
          dateExamples,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          onChanged: (val) {
            if (val != null) {
              final idx = dateExamples.indexOf(val);
              if (idx != -1) {
                setState(() {
                  _userProfile ??= {};
                  _userProfile!['FormatDate'] = formats[idx];
                });
              }
            }
          },
        ),
        _buildDropdownField(
          'Format',
          currentFormat,
          formats,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _userProfile ??= {};
                _userProfile!['FormatDate'] = val;
              });
            }
          },
        ),
        _buildTextField(
          'Preview',
          currentExample,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          enabled: false,
        ),
      ],
    );
  }

  Widget _buildTimeFormatForm(
    Color cardColor,
    Color textColor,
    Color labelColor,
    Color borderColor,
    String timeFormat,
  ) {
    final List<String> formats = [
      'HH:mm',
      'HH:mm a',
      'HH:mm A',
      'HH:mm:ss',
      'HH:mm:ss a',
      'HH:mm:ss A',
      'Custom Time',
    ];
    if (timeFormat.isNotEmpty && !formats.contains(timeFormat)) {
      formats.insert(0, timeFormat);
    }
    final currentFormat = timeFormat.isEmpty ? 'HH:mm' : timeFormat;

    String getPreview(String format, {bool useRealTime = false}) {
      if (format == 'Custom Time') return 'Custom Time';

      final h24 = useRealTime ? DateTime.now().hour : 15;
      final h12 = useRealTime ? (DateTime.now().hour % 12 == 0 ? 12 : DateTime.now().hour % 12) : 3;
      final m = useRealTime ? DateTime.now().minute.toString().padLeft(2, '0') : '30';
      final s = useRealTime ? DateTime.now().second.toString().padLeft(2, '0') : '53';
      final isPM = useRealTime ? DateTime.now().hour >= 12 : true; // 15:30 is PM

      String result = format;
      result = result.replaceAll('HH', h24.toString().padLeft(2, '0'));
      result = result.replaceAll('hh', h12.toString().padLeft(2, '0'));
      result = result.replaceAll('mm', m);
      result = result.replaceAll('ss', s);

      // Handle AM/PM
      if (result.contains('A')) {
        result = result.replaceAll('A', isPM ? 'PM' : 'AM');
      } else if (result.contains('a')) {
        result = result.replaceAll('a', isPM ? 'pm' : 'am');
      } else if (result.contains('TT') || result.contains('tt')) {
        result = result.replaceAll(RegExp(r'tt', caseSensitive: false), isPM ? 'PM' : 'AM');
      }

      // Fallback if somehow no hours were matched
      if (!result.contains(RegExp(r'[0-9]'))) {
        return '${h24.toString().padLeft(2, '0')}:$m';
      }
      return result;
    }

    final timeExamples = formats.map((f) => getPreview(f, useRealTime: false)).toList();
    final staticExample = getPreview(currentFormat, useRealTime: false);
    final dynamicExample = getPreview(currentFormat, useRealTime: true);

    return Column(
      children: [
        _buildDropdownField(
          'Time',
          staticExample,
          timeExamples,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          onChanged: (val) {
            if (val != null) {
              final idx = timeExamples.indexOf(val);
              if (idx != -1) {
                setState(() {
                  _userProfile ??= {};
                  _userProfile!['FormatTime'] = formats[idx];
                });
              }
            }
          },
        ),
        _buildDropdownField(
          'Format',
          currentFormat,
          formats,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _userProfile ??= {};
                _userProfile!['FormatTime'] = val;
              });
            }
          },
        ),
        _buildTextField(
          'Preview',
          dynamicExample,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          enabled: false,
        ),
      ],
    );
  }

  Widget _buildNumberFormatForm(
    Color cardColor,
    Color textColor,
    Color labelColor,
    Color borderColor,
    String decSep,
    String thouSep,
    String decPlaces,
    String thouGroup,
    String leadZero,
  ) {
    void updateFormatNumber({
      String? aDec,
      String? aSep,
      String? mDec,
      String? dGroup,
      String? lZero,
    }) {
      setState(() {
        _userProfile ??= {};

        Map<String, dynamic> formatNum = {};
        if (_userProfile!['FormatNumber'] != null) {
          try {
            formatNum = jsonDecode(_userProfile!['FormatNumber']);
          } catch (e) {}
        }

        if (aDec != null) {
          if (aDec == formatNum['aSep'] && aDec.isNotEmpty) {
            _showTopNotification(
              'Decimal Separator and Thousand Separator cannot be identical.',
            );
            return;
          }
          formatNum['aDec'] = aDec;
          _userProfile!['aDec'] = aDec;
        }
        if (aSep != null) {
          if (aSep == formatNum['aDec'] && aSep.isNotEmpty) {
            _showTopNotification(
              'Decimal Separator and Thousand Separator cannot be identical.',
            );
            return;
          }
          formatNum['aSep'] = aSep;
          _userProfile!['aSep'] = aSep;
        }
        if (mDec != null) {
          formatNum['mDec'] = int.tryParse(mDec) ?? 0;
          _userProfile!['mDec'] = formatNum['mDec'];
        }
        if (dGroup != null) {
          formatNum['dGroup'] =
              int.tryParse(dGroup) ?? 3; // dGroup inside JSON should be int!
          _userProfile!['dGroup'] =
              dGroup; // Flat property is string in web app payload!
        }
        if (lZero != null) {
          formatNum['lZero'] = lZero;
          _userProfile!['lZero'] = lZero;
        }

        // Ensure defaults if missing
        formatNum['aDec'] ??= ',';
        formatNum['aSep'] ??= '.';
        formatNum['mDec'] ??= 0;
        formatNum['dGroup'] ??= 3; // Ensure int
        formatNum['lZero'] ??= 'allow';

        _userProfile!['FormatNumber'] = jsonEncode(formatNum);
      });
    }

    String getPreview() {
      Map<String, dynamic> formatNum = {
        'aDec': ',',
        'aSep': '.',
        'mDec': '0',
        'dGroup': '3',
        'lZero': 'allow',
      };
      if (_userProfile?['FormatNumber'] != null) {
        try {
          formatNum = jsonDecode(_userProfile!['FormatNumber']);
        } catch (e) {}
      }

      String dec = formatNum['aDec']?.toString() ?? ',';
      String sep = formatNum['aSep']?.toString() ?? '.';
      int mDec = int.tryParse(formatNum['mDec']?.toString() ?? '0') ?? 0;
      String group = formatNum['dGroup']?.toString() ?? '3';

      // Mock formatting 17081945.123
      String whole = '17081945';
      if (group == '3')
        whole = '17${sep}081${sep}945';
      else if (group == '2')
        whole = '1${sep}70${sep}81${sep}94${sep}5'; // rough mock for dGroup=2
      else if (group == '4')
        whole = '1708${sep}1945'; // mock for dGroup=4

      if (mDec > 0) {
        String fraction = '123456789'.substring(0, mDec > 9 ? 9 : mDec);
        return '$whole$dec$fraction';
      }
      return whole;
    }

    String _extractSep(String val) {
      if (val.contains('Space')) return ' ';
      if (val.contains('None')) return '';
      if (val.contains('Apostrophe')) return "'"; // Revert to single quote
      if (val.contains('Period') || val.contains('.')) return '.';
      if (val.contains('Comma') || val.contains(',')) return ',';
      return '.';
    }

    // Pastikan nilai awal sesuai dengan opsi dropdown
    String mapDecSepToDropdown(String val) {
      if (val.contains('Period') || val.contains('.')) return "Period '.'";
      if (val.contains('Comma') || val.contains(',')) return "Comma ','";
      return "Period '.'";
    }

    String mapThouSepToDropdown(String val) {
      if (val.isEmpty || val.contains('None') || val == "None ''")
        return "None ''";
      if (val.contains('Period') || val.contains('.')) return "Period '.'";
      if (val.contains('Comma') || val.contains(',')) return "Comma ','";
      if (val.contains('Apostrophe') || val.contains("'") || val.contains(r'\'))
        return "Apostrophe '''"; // Fix UI text
      if (val.contains('Space') || val == ' ') return "Space ' '";
      return "Period '.'";
    }

    String mapLeadZeroToDropdown(String val) {
      if (val.toLowerCase() == 'deny' || val == 'Not Allow') return 'Deny';
      if (val.toLowerCase() == 'keep') return 'Keep';
      return 'Allow';
    }

    return Column(
      children: [
        _buildDropdownField(
          'Decimal Separator',
          mapDecSepToDropdown(decSep),
          ["Period '.'", "Comma ','"],
          cardColor,
          textColor,
          labelColor,
          borderColor,
          isRequired: true,
          onChanged: (val) {
            if (val != null) updateFormatNumber(aDec: _extractSep(val));
          },
        ),
        _buildTextField(
          'Decimal Places',
          decPlaces,
          cardColor,
          textColor,
          labelColor,
          borderColor,
          isRequired: true,
          onChanged: (val) {
            updateFormatNumber(mDec: val);
          },
        ),
        _buildDropdownField(
          'Thousand Separator',
          mapThouSepToDropdown(thouSep),
          ["Period '.'", "Comma ','", "Apostrophe '''", "Space ' '", "None ''"],
          cardColor,
          textColor,
          labelColor,
          borderColor,
          isRequired: true,
          onChanged: (val) {
            if (val != null) updateFormatNumber(aSep: _extractSep(val));
          },
        ),
        _buildDropdownField(
          'Thousand Grouping',
          thouGroup,
          ['3', '2', '4'],
          cardColor,
          textColor,
          labelColor,
          borderColor,
          isRequired: true,
          onChanged: (val) {
            if (val != null) updateFormatNumber(dGroup: val);
          },
        ),
        _buildDropdownField(
          'Leading Zero',
          mapLeadZeroToDropdown(leadZero),
          ['Allow', 'Deny', 'Keep'],
          cardColor,
          textColor,
          labelColor,
          borderColor,
          isRequired: true,
          onChanged: (val) {
            if (val != null) updateFormatNumber(lZero: val.toLowerCase());
          },
        ),
        _buildTextField(
          'Preview',
          getPreview(),
          cardColor,
          textColor,
          labelColor,
          borderColor,
          enabled: false,
        ),
      ],
    );
  }

  Widget _buildLoginHistoryTable(
    Color cardColor,
    Color textColor,
    Color labelColor,
    Color borderColor,
  ) {
    final List<dynamic> history = _userProfile?['LoginHistory'] ?? [];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'search...',
                hintStyle: TextStyle(color: labelColor, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: labelColor, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: borderColor),
                ),
              ),
              style: TextStyle(color: textColor, fontSize: 14),
            ),
          ),

          // Table header
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: history.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No Login History found',
                      style: TextStyle(color: labelColor),
                    ),
                  )
                : DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 40,
                    headingRowColor: MaterialStateProperty.all(
                      borderColor.withOpacity(0.3),
                    ),
                    columns: [
                      DataColumn(
                        label: Text(
                          'ID',
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'IpAddress',
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Device',
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Device Type',
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Browser',
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Login Date',
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    rows: history.map((item) {
                      String dateStr = item['LoginDate']?.toString() ?? '';
                      if (dateStr.isNotEmpty) {
                        try {
                          final parsedDate = DateTime.parse(dateStr);
                          dateStr =
                              "${parsedDate.day}-${parsedDate.month}-${parsedDate.year} ${parsedDate.hour}:${parsedDate.minute.toString().padLeft(2, '0')}";
                        } catch (e) {}
                      }
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              item['Id']?.toString() ?? '-',
                              style: TextStyle(color: textColor, fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['IpAddress']?.toString() ?? '-',
                              style: TextStyle(color: textColor, fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['Device']?.toString() ?? '-',
                              style: TextStyle(color: textColor, fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['DeviceType']?.toString() ?? '-',
                              style: TextStyle(color: textColor, fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['Browser']?.toString() ?? '-',
                              style: TextStyle(color: textColor, fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              dateStr,
                              style: TextStyle(color: textColor, fontSize: 13),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String value,
    Color cardColor,
    Color textColor,
    Color labelColor,
    Color borderColor, {
    bool enabled = true,
    bool isRequired = false,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: isRequired ? '* ' : '',
              style: const TextStyle(color: Colors.red, fontSize: 13),
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: value,
            enabled: enabled,
            onChanged: onChanged,
            style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: !enabled,
              fillColor: enabled ? cardColor : cardColor.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: borderColor),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: borderColor.withOpacity(0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> options,
    Color cardColor,
    Color textColor,
    Color labelColor,
    Color borderColor, {
    bool isRequired = false,
    GlobalKey? fieldKey,
    ValueChanged<String?>? onChanged,
  }) {
    if (value.isNotEmpty && !options.contains(value)) {
      options.add(value);
    }

    return Container(
      key: fieldKey,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: isRequired ? '* ' : '',
              style: const TextStyle(color: Colors.red, fontSize: 13),
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SearchableDropdown<String>(
            value: value.isEmpty ? null : value,
            hint: 'Select...',
            options: options.toSet().toList(),
            onChanged: (val) {
              if (onChanged != null) onChanged(val);
            },
          ),
        ],
      ),
    );
  }
}
