import 'package:flutter/material.dart';
import 'liquid_glass_container.dart';

/// A small floating pill that expands from a profile+search icon pair into
/// a full search field with a back arrow, on tap. Flutter port of the
/// `ToolbarDynamic` React component.
///
/// Usage:
/// ```dart
/// Positioned(
///   bottom: 80,
///   left: 16,
///   child: ExpandingSearchBar(onSearchChanged: (q) => ...),
/// )
/// ```
class ExpandingSearchBar extends StatefulWidget {
  const ExpandingSearchBar({super.key, this.onSearchChanged, this.hintText = 'Search'});
  final ValueChanged<String>? onSearchChanged;
  final String hintText;

  @override
  State<ExpandingSearchBar> createState() => _ExpandingSearchBarState();
}

class _ExpandingSearchBarState extends State<ExpandingSearchBar> {
  bool _isOpen = false;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _isOpen = true);
    // Wait for the frame so the field exists before requesting focus.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _close() {
    setState(() => _isOpen = false);
    _controller.clear();
    widget.onSearchChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: _isOpen ? 300 : 98,
        height: 40,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _isOpen ? _buildOpenState() : _buildClosedState(),
        ),
      ),
    );
  }

  Widget _buildClosedState() {
    return Row(
      key: const ValueKey('closed'),
      children: [
        _iconButton(Icons.person_outline, null),
        const SizedBox(width: 8),
        _iconButton(Icons.search, _open),
      ],
    );
  }

  Widget _buildOpenState() {
    return Row(
      key: const ValueKey('open'),
      children: [
        _iconButton(Icons.arrow_back, _close),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: widget.onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }
}
