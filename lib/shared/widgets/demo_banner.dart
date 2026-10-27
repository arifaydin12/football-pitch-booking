import 'package:flutter/material.dart';

/// Strip shown on top of the app in demo mode.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Demo mode. Sample data is kept in memory and resets when the page is reloaded.',
      excludeSemantics: true,
      child: Material(
        color: scheme.tertiaryContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.science_outlined,
                    size: 16, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Demo mode - sample data, resets on reload',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
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
