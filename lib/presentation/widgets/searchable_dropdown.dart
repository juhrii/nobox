import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_theme.dart';

/// A custom searchable dropdown that shows a popup with search field + scrollable list,
/// matching the NoBox web UI design exactly. Supports generic types like DropdownSearch.
class SearchableDropdown<T> extends StatefulWidget {
  final T? value;
  final String hint;
  final List<T> options;
  final ValueChanged<T?> onChanged;
  final String Function(T)? itemAsString;

  const SearchableDropdown({
    super.key,
    this.value,
    this.hint = '--select--',
    required this.options,
    required this.onChanged,
    this.itemAsString,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  bool _isOpen = false;

  String _asString(T? item) {
    if (item == null) return widget.hint;
    if (widget.itemAsString != null) {
      return widget.itemAsString!(item);
    }
    return item.toString();
  }

  void _showDropdown() async {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    setState(() {
      _isOpen = true;
    });

    final result = await showDialog<T>(
      context: context,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (ctx) => _SearchableDropdownPopup<T>(
        options: widget.options,
        selectedValue: widget.value,
        targetOffset: offset,
        targetSize: size,
        itemAsString: widget.itemAsString,
      ),
    );

    if (mounted) {
      setState(() {
        _isOpen = false;
      });
    }

    if (result != null) {
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return GestureDetector(
      onTap: _showDropdown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          border: Border.all(
            color: _isOpen
                ? AppTheme.primaryColor
                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            width: _isOpen ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.value == null ? widget.hint : _asString(widget.value),
                style: TextStyle(
                  fontSize: 14,
                  color: widget.value == null
                      ? (isDark ? AppTheme.darkTextPrimary : Colors.black)
                      : (isDark ? Colors.white : Colors.black),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? AppTheme.darkTextPrimary : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchableDropdownPopup<T> extends StatefulWidget {
  final List<T> options;
  final T? selectedValue;
  final Offset targetOffset;
  final Size targetSize;
  final String Function(T)? itemAsString;

  const _SearchableDropdownPopup({
    required this.options,
    this.selectedValue,
    required this.targetOffset,
    required this.targetSize,
    this.itemAsString,
  });

  @override
  State<_SearchableDropdownPopup<T>> createState() => _SearchableDropdownPopupState<T>();
}

class _SearchableDropdownPopupState<T> extends State<_SearchableDropdownPopup<T>> {
  final TextEditingController _searchController = TextEditingController();
  List<T> _filteredOptions = [];

  String _asString(T item) {
    if (widget.itemAsString != null) {
      return widget.itemAsString!(item);
    }
    return item.toString();
  }

  @override
  void initState() {
    super.initState();
    _filteredOptions = List.from(widget.options);
  }

  void _filterOptions(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = List.from(widget.options);
      } else {
        _filteredOptions = widget.options
            .where((opt) => _asString(opt).toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final screenHeight = MediaQuery.of(context).size.height;
    final spaceBelow = screenHeight - widget.targetOffset.dy - widget.targetSize.height;
    final showBelow = spaceBelow > 250 || spaceBelow > widget.targetOffset.dy;

    double? top;
    double? bottom;

    if (showBelow) {
      top = widget.targetOffset.dy + widget.targetSize.height + 4;
    } else {
      bottom = screenHeight - widget.targetOffset.dy + 4;
    }

    return Stack(
      children: [
        Positioned(
          left: widget.targetOffset.dx,
          top: top,
          bottom: bottom,
          width: widget.targetSize.width,
          child: Material(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            color: isDark ? AppTheme.darkSurface : Colors.white,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search field
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterOptions,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? AppTheme.darkTextSecondary.withOpacity(0.5)
                              : Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade500,
                          size: 20,
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.darkBackground.withOpacity(0.5)
                            : Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Options list
                  Flexible(
                    child: _filteredOptions.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 40,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary.withOpacity(0.5)
                                        : Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No results found',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? AppTheme.darkTextSecondary
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: _filteredOptions.length,
                            itemBuilder: (context, index) {
                              final option = _filteredOptions[index];
                              final isSelected = widget.selectedValue != null &&
                                  _asString(option) == _asString(widget.selectedValue as T);
                              return InkWell(
                                onTap: () => Navigator.pop(context, option),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  color: isSelected
                                      ? AppTheme.primaryColor.withOpacity(0.1)
                                      : Colors.transparent,
                                  child: Text(
                                    _asString(option),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? AppTheme.darkTextPrimary
                                          : AppTheme.textPrimary,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
