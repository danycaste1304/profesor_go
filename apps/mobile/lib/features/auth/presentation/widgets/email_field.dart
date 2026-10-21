import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// E-mail input with the right keyboard, autofill and no capitalization.
class EmailField extends StatelessWidget {
  const EmailField({
    super.key,
    required this.controller,
    required this.validator,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      autofillHints: const [AutofillHints.email],
      style: const TextStyle(fontSize: 17, color: AppColors.text),
      decoration: const InputDecoration(
        labelText: 'Correo',
        hintText: 'tu@correo.com',
        prefixIcon: Icon(Icons.alternate_email, color: AppColors.textMuted),
      ),
    );
  }
}
