import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'liquid_glass_container.dart';

/// Cinematic hero header: a static background image with a slow Ken-Burns
/// drift (instead of video), a serif headline with staggered fade-rise
/// entrance, subtext, and a glass CTA button.
///
/// Drop this at the top of any role's dashboard, above the existing content:
/// ```dart
/// CinematicHeroHeader(
///   headline: 'Where learning rises through the quiet.',
///   emphasisWords: const ['learning', 'through the quiet.'],
///   subtext: "Everything your child's school day needs, in one calm place.",
///   ctaLabel: 'View Fees',
///   onCtaPressed: () => context.go('/parent/fees'),
///   backgroundAsset: 'assets/backgrounds/hero_bg.png',
/// )
/// ```
class CinematicHeroHeader extends StatefulWidget {
  const CinematicHeroHeader({
    super.key,
    required this.headline,
    required this.subtext,
    required this.backgroundAsset,
    this.emphasisWords = const [],
    this.ctaLabel,
    this.onCtaPressed,
    this.height = 420,
  });

  final String headline;
  final String subtext;
  final String backgroundAsset;
  final List<String> emphasisWords;
  final String? ctaLabel;
  final VoidCallback? onCtaPressed;
  final double height;

  @override
  State<CinematicHeroHeader> createState() => _CinematicHeroHeaderState();
}

class _CinematicHeroHeaderState extends State<CinematicHeroHeader>
    with TickerProviderStateMixin {
  late final AnimationController _kenBurnsController;
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _kenBurnsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _kenBurnsController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  /// Builds the headline as a RichText, coloring any word/phrase found in
  /// [emphasisWords] a muted gray instead of the default white.
  Widget _buildHeadline(BuildContext context) {
    final baseStyle = GoogleFonts.instrumentSerif(
      fontSize: 44,
      height: 0.95,
      letterSpacing: -1.2,
      color: Colors.white,
    );
    final mutedStyle = baseStyle.copyWith(color: const Color(0xFFA6A6AA));

    // Split headline into spans, matching emphasis phrases in order.
    var remaining = widget.headline;
    final spans = <TextSpan>[];
    while (remaining.isNotEmpty) {
      String? matched;
      for (final phrase in widget.emphasisWords) {
        if (remaining.startsWith(phrase)) {
          matched = phrase;
          break;
        }
      }
      if (matched != null) {
        spans.add(TextSpan(text: matched, style: mutedStyle));
        remaining = remaining.substring(matched.length);
      } else {
        // Consume one character at a time until the next emphasis match or end.
        var i = 1;
        while (i < remaining.length &&
            !widget.emphasisWords.any((p) => remaining.substring(i).startsWith(p))) {
          i++;
        }
        spans.add(TextSpan(text: remaining.substring(0, i), style: baseStyle));
        remaining = remaining.substring(i);
      }
    }
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }

  /// Wraps [child] in a fade + slide-up entrance, starting at [delayMs].
  Widget _fadeRise({required Widget child, required int delayMs}) {
    const totalMs = 1200;
    final start = delayMs / totalMs;
    final end = (delayMs + 800) / totalMs;
    final curved = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start.clamp(0, 1), end.clamp(0, 1), curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - curved.value)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with a slow, subtle Ken Burns scale drift.
          AnimatedBuilder(
            animation: _kenBurnsController,
            builder: (context, child) {
              final scale = 1.0 + (0.04 * _kenBurnsController.value);
              return Transform.scale(scale: scale, child: child);
            },
            child: Image.asset(widget.backgroundAsset, fit: BoxFit.cover),
          ),
          // Slight darken so white text stays legible over bright image areas.
          Container(color: Colors.black.withValues(alpha: 0.18)),
          // Foreground content.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _fadeRise(delayMs: 0, child: _buildHeadline(context)),
                const SizedBox(height: 20),
                _fadeRise(
                  delayMs: 200,
                  child: Text(
                    widget.subtext,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: const Color(0xFFA6A6AA),
                      height: 1.5,
                    ),
                  ),
                ),
                if (widget.ctaLabel != null) ...[
                  const SizedBox(height: 28),
                  _fadeRise(
                    delayMs: 400,
                    child: GestureDetector(
                      onTap: widget.onCtaPressed,
                      child: LiquidGlassContainer(
                        borderRadius: BorderRadius.circular(999),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        child: Text(
                          widget.ctaLabel!,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
