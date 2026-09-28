import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';

/// The add action lives inside the navigation bar, keeping every row visible.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final palette = context.palette;
    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.card,
          border: Border(top: BorderSide(color: palette.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _NavItem(
                  path: '/home',
                  label: 'Home',
                  icon: Icons.space_dashboard_outlined,
                  selected: location.startsWith('/home'),
                ),
                _NavItem(
                  path: '/insights',
                  label: 'Insights',
                  icon: Icons.donut_small_outlined,
                  selected: location.startsWith('/insights'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton.filled(
                      tooltip: 'Add transaction',
                      style: IconButton.styleFrom(
                        backgroundColor: palette.accentFill,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.large,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/add');
                      },
                      icon: const Icon(Icons.add_rounded, size: 26),
                    ),
                  ),
                ),
                _NavItem(
                  path: '/transactions',
                  label: 'Activity',
                  semanticLabel: 'Transactions',
                  icon: Icons.swap_vert_rounded,
                  selected: location.startsWith('/transactions'),
                ),
                _NavItem(
                  path: '/profile',
                  label: 'Profile',
                  icon: Icons.person_outline_rounded,
                  selected: location.startsWith('/profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.selected,
    this.semanticLabel,
  });
  final String path;
  final String label;
  final String? semanticLabel;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.chip;
    return Expanded(
      child: Semantics(
        label: semanticLabel ?? label,
        selected: selected,
        button: true,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: AppRadii.medium,
          onTap: () {
            if (!selected) {
              HapticFeedback.selectionClick();
              context.go(path);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? palette.primarySoft : Colors.transparent,
                    borderRadius: AppRadii.pill,
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: selected ? palette.primary : palette.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? palette.primary : palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
