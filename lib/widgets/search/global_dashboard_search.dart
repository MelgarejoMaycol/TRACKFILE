import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';

class GlobalSearchOption {
  final String label;
  final String section;
  final String searchText;
  final IconData icon;
  final String type;

  const GlobalSearchOption({
    required this.label,
    required this.section,
    required this.searchText,
    required this.icon,
    required this.type,
  });
}

class GlobalDashboardSearch extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final List<GlobalSearchOption> options;
  final void Function(String value) onSubmitted;
  final void Function(GlobalSearchOption option) onSelected;

  const GlobalDashboardSearch({
    super.key,
    required this.controller,
    required this.hintText,
    required this.options,
    required this.onSubmitted,
    required this.onSelected,
  });

  @override
  State<GlobalDashboardSearch> createState() => _GlobalDashboardSearchState();
}

class _GlobalDashboardSearchState extends State<GlobalDashboardSearch> {
  final FocusNode _focusNode = FocusNode();

  String _normalize(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<GlobalSearchOption>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (option) => option.label,
      optionsBuilder: (TextEditingValue value) {
        final query = _normalize(value.text);

        if (query.isEmpty) {
          return widget.options.take(8);
        }

        return widget.options.where((option) {
          final label = _normalize(option.label);
          final search = _normalize(option.searchText);
          final type = _normalize(option.type);

          return label.contains(query) ||
              search.contains(query) ||
              type.contains(query);
        }).take(10);
      },
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          onSubmitted: widget.onSubmitted,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.14),
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Colors.white70, fontSize: 12),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.white70,
              size: 18,
            ),
            suffixIcon: IconButton(
              tooltip: context.t('common.search'),
              onPressed: () => widget.onSubmitted(textController.text),
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelectedOption, filteredOptions) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(
                maxHeight: 320,
                maxWidth: 520,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF121842),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: filteredOptions.length,
                itemBuilder: (context, index) {
                  final option = filteredOptions.elementAt(index);

                  return InkWell(
                    onTap: () => onSelectedOption(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(option.icon, color: Colors.white70, size: 19),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  option.type,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
