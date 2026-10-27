import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/data/demo/demo_repositories.dart';
import '../../core/models/app_user.dart';
import '../../core/repositories/repositories.dart';
import '../../core/state/session_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  static String? validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your e-mail';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Enter a valid e-mail address';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<SessionController>().signIn(_email.text, _password.text);
  }

  Future<void> _useDemo(AppUser user) async {
    _email.text = user.email;
    _password.text = DemoAccounts.password;
    await _submit();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isDemo = context.read<AppRepositories>().isDemo;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer.withValues(alpha: 0.55),
                    scheme.surface,
                    scheme.tertiaryContainer.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: theme.brightness == Brightness.dark
                      ? 'Switch to light theme'
                      : 'Switch to dark theme',
                  icon: Icon(theme.brightness == Brightness.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined),
                  onPressed: () =>
                      context.read<ThemeController>().toggle(theme.brightness),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(scheme: scheme, theme: theme),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: AutofillGroup(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Sign in', style: theme.textTheme.titleLarge),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.email],
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    validator: validateEmail,
                                    onChanged: (_) => session.clearError(),
                                    decoration: const InputDecoration(
                                      labelText: 'E-mail',
                                      prefixIcon: Icon(Icons.mail_outline),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _password,
                                    obscureText: _obscure,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [AutofillHints.password],
                                    onFieldSubmitted: (_) => _submit(),
                                    onChanged: (_) => session.clearError(),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Enter your password'
                                        : null,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(
                                        tooltip:
                                            _obscure ? 'Show password' : 'Hide password',
                                        icon: Icon(_obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined),
                                        onPressed: () =>
                                            setState(() => _obscure = !_obscure),
                                      ),
                                    ),
                                  ),
                                  if (session.error != null) ...[
                                    const SizedBox(height: 14),
                                    Semantics(
                                      liveRegion: true,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: scheme.errorContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.error_outline,
                                                color: scheme.onErrorContainer),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                session.error!,
                                                style: TextStyle(
                                                    color: scheme.onErrorContainer),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  FilledButton(
                                    onPressed: session.busy ? null : _submit,
                                    child: session.busy
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.5),
                                          )
                                        : const Text('Sign in'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isDemo) ...[
                        const SizedBox(height: 16),
                        _DemoAccounts(onSelect: session.busy ? null : _useDemo),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.scheme, required this.theme});

  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.sports_soccer, color: scheme.onPrimary, size: 36),
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            AppConfig.appName,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Reservations, canteen and revenue for your pitch',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts({required this.onSelect});

  final Future<void> Function(AppUser user)? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.tertiaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined,
                    size: 18, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Text('Demo accounts', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Password for both: ${DemoAccounts.password}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _AccountTile(
              user: DemoAccounts.admin,
              description: 'Everything: pricing, users, reports',
              onTap: onSelect,
            ),
            const SizedBox(height: 8),
            _AccountTile(
              user: DemoAccounts.staff,
              description: 'Reservations and canteen sales only',
              onTap: onSelect,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.user,
    required this.description,
    required this.onTap,
  });

  final AppUser user;
  final String description;
  final Future<void> Function(AppUser user)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Sign in as ${user.role.label}, ${user.email}. $description',
      excludeSemantics: true,
      onTap: onTap == null ? null : () => onTap!(user),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap == null ? null : () => onTap!(user),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    user.isAdmin
                        ? Icons.admin_panel_settings_outlined
                        : Icons.badge_outlined,
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${user.role.label} - ${user.email}',
                          style: theme.textTheme.labelLarge),
                      Text(description,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
