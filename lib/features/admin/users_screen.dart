import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme.dart';
import '../../core/models/app_user.dart';
import '../../core/repositories/repositories.dart';
import '../../shared/widgets/state_views.dart';

/// Lists accounts and lets an administrator add or remove staff.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final AuthRepository _auth = context.read<AppRepositories>().auth;
  List<AppUser> _users = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _auth.listUsers();
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final created = await showDialog<AppUser>(
      context: context,
      builder: (_) => _AddUserDialog(auth: _auth),
    );
    if (created == null) return;
    if (mounted) showMessage(context, 'Account for ${created.email} created');
    await _load();
  }

  Future<void> _delete(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${user.shownName}?'),
        content: Text(
            '${user.email} will no longer be able to use the app. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _auth.deleteUser(user.uid);
      if (mounted) showMessage(context, '${user.email} removed');
      await _load();
    } on RepositoryException catch (e) {
      if (mounted) showMessage(context, e.message, isError: true);
    } catch (_) {
      if (mounted) showMessage(context, 'Could not remove the user.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<AppUser>();
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    final pad = wide ? 24.0 : 12.0;

    final Widget body;
    if (_error != null) {
      body = ErrorState(message: describeError(_error), onRetry: _load);
    } else if (_loading && _users.isEmpty) {
      body = const LoadingView(label: 'Loading users');
    } else if (_users.isEmpty) {
      body = EmptyState(
        icon: Icons.group_outlined,
        title: 'No users',
        action: FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Add user'),
        ),
      );
    } else {
      body = ListView(
        padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  for (final user in _users) ...[
                    _UserCard(
                      user: user,
                      isMe: user.uid == me.uid,
                      onDelete: () => _delete(user),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Staff accounts can take reservations and sell canteen items. '
                  'Administrators also see reports, pricing and users.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add user'),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.isMe, required this.onDelete});

  final AppUser user;
  final bool isMe;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Semantics(
          container: true,
          label: '${user.shownName}, ${user.role.label}, ${user.email}${isMe ? ', you' : ''}',
          child: Row(
            children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  backgroundColor:
                      user.isAdmin ? scheme.primaryContainer : scheme.secondaryContainer,
                  child: Icon(
                    user.isAdmin
                        ? Icons.admin_panel_settings_outlined
                        : Icons.badge_outlined,
                    color: user.isAdmin
                        ? scheme.onPrimaryContainer
                        : scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(user.shownName,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            StatusChip(
                              label: 'You',
                              background: scheme.surfaceContainerHighest,
                              foreground: scheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      Text(user.email,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              StatusChip(
                label: user.role.label,
                background: user.isAdmin
                    ? scheme.primaryContainer
                    : scheme.secondaryContainer,
                foreground: user.isAdmin
                    ? scheme.onPrimaryContainer
                    : scheme.onSecondaryContainer,
              ),
              if (isMe)
                const SizedBox(width: 48)
              else
                IconButton(
                  tooltip: 'Remove ${user.email}',
                  icon: Icon(Icons.person_remove_outlined, color: scheme.error),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog({required this.auth});

  final AuthRepository auth;

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.staff;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.auth.createUser(
        email: _email.text.trim(),
        password: _password.text,
        role: _role,
        displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(user);
    } on RepositoryException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not create the account.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Add user'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Name (optional)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Enter an e-mail';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                      return 'Enter a valid e-mail address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Temporary password',
                    helperText: 'At least 6 characters',
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Use at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 16),
                Text('Role', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<UserRole>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: UserRole.staff, label: Text('Staff')),
                    ButtonSegment(value: UserRole.admin, label: Text('Admin')),
                  ],
                  selected: {_role},
                  onSelectionChanged:
                      _busy ? null : (s) => setState(() => _role = s.first),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
