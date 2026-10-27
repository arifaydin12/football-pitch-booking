import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../app/theme_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/models/app_user.dart';
import '../../core/repositories/repositories.dart';
import '../../core/state/canteen_controller.dart';
import '../../core/state/reports_controller.dart';
import '../../core/state/reservations_controller.dart';
import '../../core/state/session_controller.dart';
import '../../core/state/settings_controller.dart';
import '../admin/pricing_screen.dart';
import '../admin/users_screen.dart';
import '../canteen/canteen_screen.dart';
import '../reports/reports_screen.dart';
import '../reservations/reservations_screen.dart';

class _Destination {
  const _Destination({
    required this.title,
    required this.railLabel,
    required this.barLabel,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.adminOnly = false,
  });

  final String title;
  final String railLabel;
  final String barLabel;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
  final bool adminOnly;
}

final List<_Destination> _allDestinations = [
  _Destination(
    title: 'Reservations',
    railLabel: 'Reservations',
    barLabel: 'Bookings',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
    builder: (_) => const ReservationsScreen(),
  ),
  _Destination(
    title: 'Canteen',
    railLabel: 'Canteen',
    barLabel: 'Canteen',
    icon: Icons.local_cafe_outlined,
    selectedIcon: Icons.local_cafe,
    builder: (_) => const CanteenScreen(),
  ),
  _Destination(
    title: 'Revenue reports',
    railLabel: 'Reports',
    barLabel: 'Reports',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    builder: (_) => const ReportsScreen(),
    adminOnly: true,
  ),
  _Destination(
    title: 'Pricing and products',
    railLabel: 'Pricing',
    barLabel: 'Pricing',
    icon: Icons.sell_outlined,
    selectedIcon: Icons.sell,
    builder: (_) => const PricingScreen(),
    adminOnly: true,
  ),
  _Destination(
    title: 'Users',
    railLabel: 'Users',
    barLabel: 'Users',
    icon: Icons.group_outlined,
    selectedIcon: Icons.group,
    builder: (_) => const UsersScreen(),
    adminOnly: true,
  ),
];

/// Signed-in area: navigation plus the screens the user's role may see.
/// Staff get reservations and canteen; administrators also get reports,
/// pricing and user management.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.user});

  final AppUser user;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  List<_Destination> get _destinations => [
        for (final d in _allDestinations)
          if (!d.adminOnly || widget.user.isAdmin) d,
      ];

  @override
  Widget build(BuildContext context) {
    final repos = context.read<AppRepositories>();
    return MultiProvider(
      providers: [
        Provider<AppUser>.value(value: widget.user),
        ChangeNotifierProvider(
          create: (_) => ReservationsController(
            reservations: repos.reservations,
            settings: repos.settings,
            clock: repos.clock,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => CanteenController(repository: repos.canteen, clock: repos.clock),
        ),
        if (widget.user.isAdmin) ...[
          ChangeNotifierProvider(
            create: (_) => ReportsController(
              reservations: repos.reservations,
              canteen: repos.canteen,
              clock: repos.clock,
            ),
          ),
          ChangeNotifierProvider(create: (_) => SettingsController(repos.settings)),
        ],
      ],
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final destinations = _destinations;
    final index = _index.clamp(0, destinations.length - 1);
    final current = destinations[index];
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= Breakpoints.compact;
    final extended = width >= Breakpoints.expanded;

    final body = KeyedSubtree(
      key: ValueKey(current.title),
      child: current.builder(context),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(current.title),
        actions: [
          const _ThemeButton(),
          _AccountMenu(user: widget.user),
          const SizedBox(width: 8),
        ],
      ),
      body: useRail
          ? Row(
              children: [
                NavigationRail(
                  extended: extended,
                  selectedIndex: index,
                  labelType:
                      extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: extended
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sports_soccer,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(AppConfig.appName,
                                  style: Theme.of(context).textTheme.titleMedium),
                            ],
                          )
                        : Icon(Icons.sports_soccer,
                            color: Theme.of(context).colorScheme.primary),
                  ),
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.railLabel),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.barLabel,
                  ),
              ],
            ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Switch to light theme' : 'Switch to dark theme',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () =>
          context.read<ThemeController>().toggle(Theme.of(context).brightness),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: 'Account menu for ${user.shownName}',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == 'signout') context.read<SessionController>().signOut();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.shownName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.onSurface)),
              Text('${user.role.label} - ${user.email}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'signout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.logout),
            title: Text('Sign out'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            user.shownName.isEmpty ? '?' : user.shownName[0].toUpperCase(),
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
