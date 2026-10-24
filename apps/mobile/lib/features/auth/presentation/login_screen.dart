import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_card.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_icons.dart';
import '../domain/auth_validators.dart';
import 'auth_controller.dart';
import 'widgets/auth_message_banner.dart';
import 'widgets/email_field.dart';
import 'widgets/password_field.dart';
import 'widgets/pixel_logo.dart';

/// Google sign-in in real builds; e-mail/password remains in the local demo.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const Key emailKey = Key('login_email');
  static const Key passwordKey = Key('login_password');
  static const Key submitKey = Key('login_submit');
  static const Key registerLinkKey = Key('login_register_link');
  static const Key demoFillKey = Key('login_demo_fill');
  static const Key googleKey = Key('login_google');

  static const String demoHint = 'Modo demo: cualquier correo válido funciona';
  static const String demoEmail = 'player@profesorgo.local';
  static const String demoPassword = 'player12345';

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    // Navigation happens in the router guard when the auth stream emits.
    await ref
        .read(authControllerProvider.notifier)
        .signIn(_email.text, _password.text);
  }

  void _fillDemoCredentials() {
    _email.text = LoginScreen.demoEmail;
    _password.text = LoginScreen.demoPassword;
    ref.read(authControllerProvider.notifier).clearMessages();
  }

  void _goToRegister() {
    ref.read(authControllerProvider.notifier).clearMessages();
    context.go(AppRoutes.register);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return AppScaffold(
      title: 'Iniciar sesión',
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const PixelLogo(tagline: 'Feria universitaria'),
                const SizedBox(height: 28),
                if (AppConfig.isDemoMode) ...[
                  PixelCard(
                    borderColor: AppColors.accentAlt,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const PixelIcon(
                              PixelIcons.flask,
                              color: AppColors.accentAlt,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                LoginScreen.demoHint,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: LoginScreen.demoFillKey,
                            onPressed: auth.loading
                                ? null
                                : _fillDemoCredentials,
                            icon: const PixelIcon(PixelIcons.bolt),
                            label: const Text('Usar jugador demo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (auth.error != null) ...[
                  AuthMessageBanner(
                    message: auth.error!,
                    onDismiss: controller.clearMessages,
                  ),
                  const SizedBox(height: 16),
                ],
                if (auth.notice != null) ...[
                  AuthMessageBanner(
                    message: auth.notice!,
                    kind: AuthBannerKind.info,
                    onDismiss: controller.clearMessages,
                  ),
                  const SizedBox(height: 16),
                ],
                if (AppConfig.isDemoMode) ...[
                  EmailField(
                    key: LoginScreen.emailKey,
                    controller: _email,
                    validator: AuthValidators.email,
                    enabled: !auth.loading,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    key: LoginScreen.passwordKey,
                    controller: _password,
                    validator: AuthValidators.password,
                    enabled: !auth.loading,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  PixelButton(
                    key: LoginScreen.submitKey,
                    label: 'Entrar',
                    icon: PixelIcons.login,
                    loading: auth.loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    key: LoginScreen.registerLinkKey,
                    onPressed: auth.loading ? null : _goToRegister,
                    child: const Text('¿No tienes cuenta? Crear cuenta'),
                  ),
                ] else ...[
                  PixelButton(
                    key: LoginScreen.googleKey,
                    label: 'Continuar con Google',
                    icon: PixelIcons.login,
                    loading: auth.loading,
                    onPressed: () => controller.signInWithGoogle(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Usa tu cuenta personal de Google para jugar.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
