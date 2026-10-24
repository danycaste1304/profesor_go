import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_icons.dart';
import '../domain/auth_validators.dart';
import 'auth_controller.dart';
import 'widgets/auth_message_banner.dart';
import 'widgets/email_field.dart';
import 'widgets/password_field.dart';
import 'widgets/pixel_logo.dart';
import '../../../core/widgets/pixel_icon.dart';

/// Account creation: e-mail, password and an optional nickname. On success
/// the user is signed in and the router redirects to `/map`.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  static const Key emailKey = Key('register_email');
  static const Key passwordKey = Key('register_password');
  static const Key displayNameKey = Key('register_display_name');
  static const Key submitKey = Key('register_submit');
  static const Key loginLinkKey = Key('register_login_link');

  static const String createdMessage = 'Cuenta creada';

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    // The messenger lives above the navigator, so the snack bar survives the
    // router redirect to /map that follows a successful sign-up.
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .signUp(_email.text, _password.text, displayName: _displayName.text);
    if (!ok) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(RegisterScreen.createdMessage),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _goToLogin() {
    ref.read(authControllerProvider.notifier).clearMessages();
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return AppScaffold(
      title: 'Crear cuenta',
      leading: IconButton(
        tooltip: 'Volver',
        icon: const PixelIcon(PixelIcons.arrowBack),
        onPressed: auth.loading ? null : _goToLogin,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const PixelLogo(tagline: 'Nuevo jugador'),
                const SizedBox(height: 24),
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
                EmailField(
                  key: RegisterScreen.emailKey,
                  controller: _email,
                  validator: AuthValidators.email,
                  enabled: !auth.loading,
                ),
                const SizedBox(height: 16),
                PasswordField(
                  key: RegisterScreen.passwordKey,
                  controller: _password,
                  validator: AuthValidators.password,
                  label:
                      'Contraseña (mínimo '
                      '${AuthValidators.minPasswordLength} caracteres)',
                  textInputAction: TextInputAction.next,
                  enabled: !auth.loading,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: RegisterScreen.displayNameKey,
                  controller: _displayName,
                  validator: AuthValidators.displayName,
                  enabled: !auth.loading,
                  maxLength: AuthValidators.maxDisplayNameLength,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.nickname],
                  onFieldSubmitted: (_) => _submit(),
                  style: const TextStyle(fontSize: 17, color: AppColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Apodo (opcional)',
                    hintText: 'Cómo te verán en el juego',
                    prefixIcon: PixelIcon(
                      PixelIcons.badge,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PixelButton(
                  key: RegisterScreen.submitKey,
                  label: 'Crear cuenta',
                  icon: PixelIcons.personAdd,
                  loading: auth.loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: RegisterScreen.loginLinkKey,
                  onPressed: auth.loading ? null : _goToLogin,
                  child: const Text('¿Ya tienes cuenta? Iniciar sesión'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
