import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../providers/auth_providers.dart';

String compactAccountListIdentifier(String value) {
  const maxLength = 24;
  final trimmed = value.trim();
  if (trimmed.length <= maxLength) return trimmed;
  final atIndex = trimmed.indexOf('@');
  if (atIndex <= 0) {
    return '${trimmed.substring(0, 8)}...${trimmed.substring(trimmed.length - 8)}';
  }
  final localPart = trimmed.substring(0, atIndex);
  final domain = trimmed.substring(atIndex + 1);
  final localPrefix = localPart.length <= 8 ? localPart : localPart.substring(0, 8);
  final visibleDomain = domain.length <= 14 ? domain : domain.substring(domain.length - 14);
  return '$localPrefix...@$visibleDomain';
}

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.onSignOut});
  final Future<void> Function()? onSignOut;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _isSigningOut = false;

  void _redirectToSettingsIfSignedOut() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRoutes.settings);
    });
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      final action = widget.onSignOut;
      if (action != null) {
        await action();
      } else {
        await ref.read(authControllerProvider).signOut();
      }
      if (!mounted) return;
      context.go(AppRoutes.settings);
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authResponse = ref.watch(authSessionProvider);

    if (authResponse == null) {
      _redirectToSettingsIfSignedOut();
      return const Scaffold(body: SizedBox.shrink());
    }

    final email = authResponse.email ?? authResponse.userId ?? '用户';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.account)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            _SignedInAccountCard(
              email: email,
              isSigningOut: _isSigningOut,
              onSignOut: _signOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInAccountCard extends StatelessWidget {
  const _SignedInAccountCard({
    required this.email,
    required this.isSigningOut,
    required this.onSignOut,
  });
  final String email;
  final bool isSigningOut;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(email),
            subtitle: Text(email),
          ),
          const Divider(height: 1),
          ListTile(
            leading: isSigningOut
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            title: Text('退出'),
            onTap: isSigningOut ? null : onSignOut,
          ),
        ],
      ),
    );
  }
}
