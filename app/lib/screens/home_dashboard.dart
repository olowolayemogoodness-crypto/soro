import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/soro_strings.dart';
import '../theme/soro_theme.dart';

/// Deep crimson banner with the one clear main action of the home screen.
class SoroHeroCard extends StatelessWidget {
  const SoroHeroCard({super.key, required this.language, required this.onStart});

  final SoroLanguage language;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SoroTokens.s24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SoroTokens.crimson, SoroTokens.crimsonDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(SoroTokens.rLg),
        boxShadow: SoroTokens.e2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoroLocalizedText(
                  SoroStrings.tr(language, 'heroTitle'),
                  language: language,
                  style: SoroTokens.serif(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: SoroTokens.paper,
                  ),
                ),
                const SizedBox(height: SoroTokens.s8),
                SoroLocalizedText(
                  SoroStrings.tr(language, 'heroPromise'),
                  language: language,
                  style: SoroTokens.sans(fontSize: 15, color: SoroTokens.paper),
                ),
                const SizedBox(height: SoroTokens.s16),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: SoroTokens.minTapTarget,
                  ),
                  child: FilledButton(
                    key: const Key('hero-start-problem-button'),
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      backgroundColor: SoroTokens.paper,
                      foregroundColor: SoroTokens.crimsonDeep,
                      padding: const EdgeInsets.symmetric(
                        horizontal: SoroTokens.s24,
                        vertical: SoroTokens.s12,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      SoroStrings.tr(language, 'heroCta'),
                      style: SoroTokens.sans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SoroTokens.crimsonDeep,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SoroTokens.s16),
          ExcludeSemantics(
            child: SvgPicture.asset(
              'assets/mascot/soro-ilu-encouraging.svg',
              key: const Key('ilu-mascot-svg'),
              width: 88,
              height: 88,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wide soft-tinted card that opens the board with one problem.
class SoroLearnCard extends StatelessWidget {
  const SoroLearnCard({
    super.key,
    required this.language,
    required this.tint,
    required this.accent,
    required this.icon,
    required this.tag,
    required this.title,
    required this.line,
    required this.onTap,
  });

  final SoroLanguage language;
  final Color tint;
  final Color accent;
  final IconData icon;
  final String tag;
  final String title;
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$tag. $title. $line',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: tint,
        borderRadius: BorderRadius.circular(SoroTokens.rLg),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SoroTokens.rLg),
          onTap: onTap,
          child: Container(
            constraints:
                const BoxConstraints(minHeight: SoroTokens.minTapTarget * 2),
            padding: const EdgeInsets.all(SoroTokens.s16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SoroTokens.rLg),
              boxShadow: SoroTokens.e1,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: Icon(icon, color: SoroTokens.paper, size: 28),
                ),
                const SizedBox(width: SoroTokens.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag,
                        style: SoroTokens.sans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: SoroTokens.ink2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: SoroTokens.serif(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line,
                        style: SoroTokens.sans(
                          fontSize: 14,
                          color: SoroTokens.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: SoroTokens.ink2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Equal soft-tinted quick link tile: label on top, round coloured icon below.
class SoroQuickTile extends StatelessWidget {
  const SoroQuickTile({
    super.key,
    required this.label,
    required this.icon,
    required this.tint,
    required this.accent,
    this.onTap,
    this.soonNote,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final Color accent;
  final VoidCallback? onTap;

  /// When set the tile is disabled and shows this note (for example 'Soon').
  final String? soonNote;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: soonNote == null ? label : '$label, $soonNote',
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.7 : 1,
        child: Material(
          color: tint,
          borderRadius: BorderRadius.circular(SoroTokens.rMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(SoroTokens.rMd),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(SoroTokens.s12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SoroTokens.rMd),
                boxShadow: SoroTokens.e1,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: SoroTokens.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (soonNote != null)
                    Text(
                      soonNote!,
                      style: SoroTokens.sans(
                        fontSize: 12.5,
                        color: SoroTokens.ink2,
                      ),
                    ),
                  const SizedBox(height: SoroTokens.s12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration:
                          BoxDecoration(color: accent, shape: BoxShape.circle),
                      child: Icon(icon, color: SoroTokens.paper, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation: Home, Study, Test, Chat, More.
class SoroBottomNav extends StatelessWidget {
  const SoroBottomNav({
    super.key,
    required this.language,
    required this.selected,
    required this.onSelect,
  });

  final SoroLanguage language;
  final int selected;
  final ValueChanged<int> onSelect;

  static const List<(String, IconData)> _items = [
    ('navHome', Icons.home_rounded),
    ('navStudy', Icons.menu_book_rounded),
    ('navTest', Icons.fact_check_rounded),
    ('navChat', Icons.chat_bubble_rounded),
    ('navMore', Icons.apps_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SoroTokens.paper,
      elevation: 8,
      shadowColor: const Color.fromRGBO(92, 74, 42, 0.25),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (int i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  key: Key('nav-${_items[i].$1}'),
                  label: SoroStrings.tr(language, _items[i].$1),
                  icon: _items[i].$2,
                  selected: i == selected,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? SoroTokens.crimson : SoroTokens.ink2;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: SoroTokens.s8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: SoroTokens.mFast,
                padding: const EdgeInsets.symmetric(
                  horizontal: SoroTokens.s16,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: selected ? SoroTokens.blush : Colors.transparent,
                  borderRadius: BorderRadius.circular(SoroTokens.rPill),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SoroTokens.sans(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
