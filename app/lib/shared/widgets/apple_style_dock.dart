import 'package:flutter/material.dart';
import 'liquid_glass_container.dart';

class DockItemData {
  const DockItemData({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// A floating, pill-shaped bottom dock. Each icon scales up on hover (web/
/// desktop) or press (mobile), with a small label appearing above it —
/// a Flutter port of the macOS-dock-style React component.
///
/// Usage:
/// ```dart
/// Positioned(
///   bottom: 16,
///   left: 0,
///   right: 0,
///   child: Center(
///     child: AppleStyleDock(items: [
///       DockItemData(icon: Icons.home_outlined, label: 'Home', onTap: () => context.go('/parent')),
///       DockItemData(icon: Icons.currency_rupee, label: 'Fees', onTap: () => context.go('/parent/fees')),
///       ...
///     ]),
///   ),
/// )
/// ```
class AppleStyleDock extends StatelessWidget {
  const AppleStyleDock({super.key, required this.items});
  final List<DockItemData> items;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) => _DockIcon(item: item)).toList(),
      ),
    );
  }
}

class _DockIcon extends StatefulWidget {
  const _DockIcon({required this.item});
  final DockItemData item;

  @override
  State<_DockIcon> createState() => _DockIconState();
}

class _DockIconState extends State<_DockIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.item.onTap,
        onTapDown: (_) => setState(() => _hovered = true),
        onTapUp: (_) => setState(() => _hovered = false),
        onTapCancel: () => setState(() => _hovered = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _hovered ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.item.label,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
              AnimatedScale(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                scale: _hovered ? 1.3 : 1.0,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.item.icon, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
