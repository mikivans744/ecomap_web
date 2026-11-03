import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneInputField extends StatefulWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.decoration,
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final InputDecoration? decoration;

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  static const _countries = <({String code, String name, String format})>[
    (code: '+591', name: 'Bolivia', format: '### ### ##'),
    (code: '+51', name: 'Perú', format: '### ### ###'),
    (code: '+57', name: 'Colombia', format: '### ### ####'),
    (code: '+52', name: 'México', format: '### ### ####'),
    (code: '+54', name: 'Argentina', format: '### ### ####'),
    (code: '+56', name: 'Chile', format: '# #### ####'),
    (code: '+34', name: 'España', format: '### ### ###'),
    (code: '+1', name: 'USA/Canadá', format: '### ### ####'),
  ];

  late String _selectedCountry;
  late final TextEditingController _numberController;

  @override
  void initState() {
    super.initState();
    final existing = widget.controller.text.trim();
    final country = _countries.firstWhere(
      (item) => existing.startsWith(item.code),
      orElse: () => _countries.first,
    );
    _selectedCountry = country.code;
    final number = existing.startsWith(_selectedCountry)
        ? existing.substring(_selectedCountry.length)
        : existing;
    _numberController = TextEditingController(
      text: number.replaceAll(RegExp(r'\D'), ''),
    );
    _numberController.addListener(_syncOuterController);
    _syncOuterController();
  }

  @override
  void dispose() {
    _numberController
      ..removeListener(_syncOuterController)
      ..dispose();
    super.dispose();
  }

  void _syncOuterController() {
    final value = _numberController.text;
    final formatted = value.isEmpty ? '' : '$_selectedCountry $value';
    if (widget.controller.text != formatted) widget.controller.text = formatted;
  }

  @override
  Widget build(BuildContext context) {
    final country =
        _countries.firstWhere((item) => item.code == _selectedCountry);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 135,
              child: DropdownButtonFormField<String>(
                value: _selectedCountry,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _countries
                    .map((item) => DropdownMenuItem(
                          value: item.code,
                          child: Text(item.code),
                        ))
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedCountry = value);
                  _syncOuterController();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _numberController,
                keyboardType: widget.keyboardType ?? TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: widget.decoration ??
                    const InputDecoration(
                      labelText: 'Número de teléfono',
                      hintText: '999 888 777',
                      border: OutlineInputBorder(),
                    ),
                validator: (_) => widget.validator?.call(
                  _numberController.text.isEmpty
                      ? ''
                      : '$_selectedCountry ${_numberController.text}',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Formato: ${country.format}',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
