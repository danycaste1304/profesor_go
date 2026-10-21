import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Password input with a show / hide toggle (min 48x48 target).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.validator,
    this.label = 'Contraseña',
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.enabled = true,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final String label;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      obscureText: _obscure,
      enabled: widget.enabled,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      style: const TextStyle(fontSize: 17, color: AppColors.text),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: AppColors.textMuted,
          ),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
