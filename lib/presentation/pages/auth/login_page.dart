import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/admin_auth_provider.dart';
import '../../../core/auth/admin_auth_state.dart';
import '../../../core/theme/app_colors.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _authTimeoutSnackShown = false;
  String? _errorMessage;

  static const String _authTimeoutMessage =
      'No se pudo verificar la sesión, intenta de nuevo';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      try {
        await ref.read(adminSignInProvider)(
          email: _emailController.text.trim().toLowerCase(),
          password: _passwordController.text,
        );
      } on FirebaseAuthException catch (error) {
        if (!mounted) return;
        final message = error.code == 'not-admin'
            ? 'Este usuario no tiene permisos de administrador.'
            : 'No se pudo iniciar sesión. Verifica las credenciales.';
        setState(() => _errorMessage = message);
      } on FirebaseException catch (error) {
        if (!mounted) return;
        setState(
          () => _errorMessage =
              'No se pudo verificar el perfil administrativo (${error.code}). '
                  'Revisa la conexión y las reglas de Firestore.',
        );
      } catch (error) {
        if (!mounted) return;
        setState(
          () => _errorMessage =
              'No se pudo verificar el acceso administrativo. Intenta nuevamente.',
        );
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(isAdminProvider);
    ref.listen(isAdminProvider, (_, next) {
      if (next.valueOrNull?.message == _authTimeoutMessage) {
        _showAuthTimeoutSnackBar();
      }
    });
    if (authAsync.valueOrNull?.status == AdminAuthStatus.error &&
        authAsync.valueOrNull?.message == _authTimeoutMessage) {
      _showAuthTimeoutSnackBar();
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                if (constraints.maxWidth >= 900)
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary,
                            AppColors.primaryDark,
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(56),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.eco_rounded,
                              color: Colors.white,
                              size: 64,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'ECOMAP Web',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Panel administrativo para la red de reciclaje y apoyo comunitario.',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Icon(
                                    Icons.admin_panel_settings_outlined,
                                    size: 52,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Acceso administrador',
                                    textAlign: TextAlign.center,
                                    style:
                                        theme.textTheme.headlineSmall?.copyWith(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ingresa tus credenciales para continuar.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  TextFormField(
                                    key: const Key('login_email_field'),
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    style: const TextStyle(letterSpacing: 0.5),
                                    decoration: const InputDecoration(
                                      labelText: 'Correo electrónico',
                                      prefixIcon: Icon(Icons.email_outlined),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 15,
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Ingresa tu correo';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    key: const Key('login_password_field'),
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    autofillHints: const [
                                      AutofillHints.password
                                    ],
                                    style: const TextStyle(letterSpacing: 0.5),
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon:
                                          const Icon(Icons.lock_outline),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 15,
                                      ),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Ingresa tu contraseña';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    child: FilledButton.icon(
                                      key: const Key('login_submit_button'),
                                      onPressed: _isSubmitting ? null : _submit,
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
                                        ),
                                      ),
                                      icon: _isSubmitting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.login_outlined),
                                      label: Text(
                                        _isSubmitting
                                            ? 'Validando acceso...'
                                            : 'Ingresar al panel',
                                        style: const TextStyle(
                                          letterSpacing: 0.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Acceso restringido para administradores autorizados.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAuthTimeoutSnackBar() {
    if (_authTimeoutSnackShown) return;
    _authTimeoutSnackShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(
        content: Text(_authTimeoutMessage),
      ));
    });
  }
}
