import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LicensePlateField extends StatelessWidget {
  const LicensePlateField({
    super.key,
    required this.controller,
    this.validator,
    this.isVehicle = true,
    this.onChanged,
    this.suffixIcon,
    this.textCapitalization,
    this.decoration,
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool isVehicle;
  final ValueChanged<String>? onChanged;
  final Widget? suffixIcon;
  final TextCapitalization? textCapitalization;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization ?? TextCapitalization.characters,
      decoration: decoration ??
          InputDecoration(
            labelText: 'Placa *',
            hintText: isVehicle ? 'ABC-123' : 'BIC-456',
            helperText: 'Formato: 3 letras - 3 números (ABC-123)',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.directions_car_outlined),
            suffixIcon: suffixIcon,
          ),
      inputFormatters: [_LicensePlateFormatter()],
      validator: validator,
      onChanged: onChanged,
    );
  }
}

class _LicensePlateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.toUpperCase().replaceAll('-', '');
    text = text.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (text.length > 6) text = text.substring(0, 6);
    if (text.length > 3) text = '${text.substring(0, 3)}-${text.substring(3)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
