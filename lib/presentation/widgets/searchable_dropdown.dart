import 'package:flutter/material.dart';

/// A custom searchable dropdown that shows a popup with search field + scrollable list,
/// matching the NoBox web UI design exactly.
class SearchableDropdown extends StatefulWidget {
  final String? value;
  final String hint;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const SearchableDropdown({
    super.key,
    this.value,
    this.hint = '--select--',
    required this.options,
    required this.onChanged,
  });

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  bool _isOpen = false;

  void _showDropdown() async {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    setState(() {
      _isOpen = true;
    });

    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (ctx) => _SearchableDropdownPopup(
        options: widget.options,
        selectedValue: widget.value,
        targetOffset: offset,
        targetSize: size,
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
    return GestureDetector(
      onTap: _showDropdown,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: _isOpen ? Colors.blue : Colors.grey.shade300,
            width: _isOpen ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.value == null ? '--select--' : widget.value!,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down, 
              color: Colors.grey.shade700,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchableDropdownPopup extends StatefulWidget {
  final List<String> options;
  final String? selectedValue;
  final Offset targetOffset;
  final Size targetSize;

  const _SearchableDropdownPopup({
    required this.options,
    this.selectedValue,
    required this.targetOffset,
    required this.targetSize,
  });

  @override
  State<_SearchableDropdownPopup> createState() => _SearchableDropdownPopupState();
}

class _SearchableDropdownPopupState extends State<_SearchableDropdownPopup> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredOptions = [];

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
            .where((opt) => opt.toLowerCase().contains(query.toLowerCase()))
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
              side: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search field
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterOptions,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search...',
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 18),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade500),
                        ),
                      ),
                    ),
                  ),
                  // Options list
                  Flexible(
                    child: _filteredOptions.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No results found', 
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: _filteredOptions.length,
                            itemBuilder: (context, index) {
                              final option = _filteredOptions[index];
                              return InkWell(
                                onTap: () => Navigator.pop(context, option),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Text(
                                    option,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
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
