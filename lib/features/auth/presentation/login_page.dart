import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.signIn(_email.text, _password.text);

      // Signing in is not the same as being allowed in. Verify the role before
      // the router does, so a salon owner gets a clear explanation instead of
      // being bounced back to this screen with no reason given.
      final user = repo.currentUser;
      if (user != null) {
        final admin = await repo.resolveAdmin(user);
        if (admin == null || !admin.isSuperAdmin) {
          await repo.signOut();
          if (mounted) {
            setState(() => _error =
                'This account is not a super administrator. The console is '
                'restricted to users whose profile carries the super_admin role.');
          }
          return;
        }
      }
      // Success: the router redirect reacts to the session and navigates.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendly(e.code));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(String code) => switch (code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'Incorrect email or password.',
        'invalid-email' => 'That email address is not valid.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Try again shortly.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => 'Sign-in failed. Please try again.',
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 410),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: t.colorScheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.shield_moon_outlined,
                              size: 26, color: t.colorScheme.onPrimary),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Super Admin Console',
                        textAlign: TextAlign.center,
                        style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Qvrix Luxe platform operations',
                        textAlign: TextAlign.center,
                        style: t.textTheme.bodySmall
                            ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _email,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email, size: 19),
                        ),
                        validator: (v) =>
                            (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 19),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 19,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Enter your password' : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: t.colorScheme.errorContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 17, color: t.colorScheme.error),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: t.textTheme.bodySmall
                                      ?.copyWith(color: t.colorScheme.onErrorContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              )
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Access is limited to platform administrators and is '
                        'enforced by database security rules.',
                        textAlign: TextAlign.center,
                        style: t.textTheme.labelSmall
                            ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
