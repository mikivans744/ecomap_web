import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/recolector_entity.dart';
import '../../../../domain/repositories/recolector_repository.dart';

class RecolectorFormDialog extends StatefulWidget {
  const RecolectorFormDialog({
    required this.repository,
    this.recolector,
    super.key,
  });

  final RecolectorRepository repository;
  final RecolectorEntity? recolector;

  @override
  State<RecolectorFormDialog> createState() => _RecolectorFormDialogState();
}

class _RecolectorFormDialogState extends State<RecolectorFormDialog> {
  static const List<String> _zones = [
    'Zona Norte',
    'Zona Sur',
    'Zona Este',
    'Zona Oeste',
    'Centro',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _experienceController;
  late final TextEditingController _plateController;
  late final TextEditingController _brandController;
  late final TextEditingController _capacityController;
  Timer? _plateDebounce;
  late String _zone;
  late String _transport;
  bool _plateCheckPending = false;
  bool? _plateAvailable;
  bool _saving = false;

  bool get _usesVehicle => _transport == 'vehiculo';

  @override
  void initState() {
    super.initState();
    final recolector = widget.recolector;
    final vehicle = recolector?.vehiculoInfo ?? const <String, dynamic>{};
    _nameController = TextEditingController(
      text: recolector?.nombreCompleto ?? '',
    );
    _phoneController = TextEditingController(text: recolector?.telefono ?? '');
    _experienceController = TextEditingController(
      text: recolector?.aniosExperiencia.toString() ?? '',
    );
    _plateController = TextEditingController(
      text: vehicle['placa'] as String? ?? '',
    );
    _brandController = TextEditingController(
      text: vehicle['marca'] as String? ?? '',
    );
    _capacityController = TextEditingController(
      text: vehicle['capacidad']?.toString() ?? '',
    );
    _zone =
        recolector?.zona.isNotEmpty == true ? recolector!.zona : _zones.first;
    _transport = recolector?.medioTransporte ?? 'vehiculo';
    if (recolector != null &&
        _usesVehicle &&
        _plateController.text.isNotEmpty) {
      _schedulePlateCheck(_plateController.text);
    }
  }

  @override
  void dispose() {
    _plateDebounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _experienceController.dispose();
    _plateController.dispose();
    _brandController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _schedulePlateCheck(String value) {
    _plateDebounce?.cancel();
    final plate = value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (plate.isEmpty) {
      setState(() {
        _plateCheckPending = false;
        _plateAvailable = null;
      });
      return;
    }
    setState(() {
      _plateCheckPending = true;
      _plateAvailable = null;
    });
    _plateDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final available = await widget.repository.isPlateAvailable(
          plate,
          excludingId: widget.recolector?.id,
        );
        if (!mounted) return;
        setState(() {
          _plateCheckPending = false;
          _plateAvailable = available;
        });
        if (!available) _formKey.currentState?.validate();
      } catch (error, stackTrace) {
        debugPrint('No se pudo validar la placa $plate: $error\n$stackTrace');
        if (!mounted) return;
        setState(() {
          _plateCheckPending = false;
          _plateAvailable = null;
        });
      }
    });
  }

  Future<bool> _checkPlateBeforeSave() async {
    if (!_usesVehicle) return true;
    final plate = _plateController.text.trim();
    if (plate.isEmpty) return false;
    setState(() => _plateCheckPending = true);
    _plateDebounce?.cancel();
    try {
      final available = await widget.repository.isPlateAvailable(
        plate,
        excludingId: widget.recolector?.id,
      );
      if (!mounted) return false;
      setState(() {
        _plateAvailable = available;
        _plateCheckPending = false;
      });
      return available;
    } catch (error, stackTrace) {
      debugPrint('Error validando placa antes de guardar: $error\n$stackTrace');
      if (mounted) {
        setState(() => _plateCheckPending = false);
        _showError('No se pudo verificar la disponibilidad de la placa.');
      }
      return false;
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_usesVehicle && !await _checkPlateBeforeSave()) {
      if (mounted) _formKey.currentState!.validate();
      return;
    }

    setState(() => _saving = true);
    final previous = widget.recolector;
    final vehicleInfo = _usesVehicle
        ? <String, dynamic>{
            'placa': _plateController.text.trim().toUpperCase(),
            'marca': _brandController.text.trim(),
            'capacidad': double.parse(_capacityController.text.trim()),
            'estadoActivo': previous?.estadoActivo ?? true,
          }
        : <String, dynamic>{};
    final experience = int.parse(_experienceController.text.trim());

    try {
      if (previous == null) {
        await widget.repository.create(
          RecolectorEntity(
            id: '',
            userId: '',
            nombreCompleto: _nameController.text.trim(),
            telefono: _phoneController.text.trim(),
            zona: _zone,
            medioTransporte: _transport,
            aniosExperiencia: experience,
            estadoActivo: true,
            kilosOfertados: 0,
            totalOfertas: 0,
            vehiculoInfo: vehicleInfo,
            fechaRegistro: DateTime.now(),
          ),
        );
      } else {
        await widget.repository.update(previous.id, {
          'nombreCompleto': _nameController.text.trim(),
          'telefono': _phoneController.text.trim(),
          'zona': _zone,
          'medioTransporte': _transport,
          'aniosExperiencia': experience,
          'vehiculoInfo': vehicleInfo,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } on RecolectorPlateAlreadyInUse catch (error) {
      _showError(error.toString());
    } catch (error, stackTrace) {
      debugPrint('No se pudo guardar el recolector: $error\n$stackTrace');
      _showError('No se pudo guardar el recolector. Intenta nuevamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.recolector != null;
    final zones = _zone.isNotEmpty && !_zones.contains(_zone)
        ? <String>[_zone, ..._zones]
        : _zones;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? 'Editar recolector' : 'Nuevo recolector',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          key: const Key('recolector_name_field'),
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo *',
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Ingresa el nombre completo'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('recolector_phone_field'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono *',
                            hintText: '+57 3001234567',
                          ),
                          validator: (value) {
                            final phone = value?.trim() ?? '';
                            if (phone.isEmpty) return 'Ingresa un teléfono';
                            if (!RegExp(r'^\+\d{1,3}\s?\d{7,12}$')
                                .hasMatch(phone)) {
                              return 'Usa código de país y 7 a 12 dígitos';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _zone,
                          decoration:
                              const InputDecoration(labelText: 'Zona *'),
                          items: zones
                              .map((zone) => DropdownMenuItem(
                                    value: zone,
                                    child: Text(zone),
                                  ))
                              .toList(growable: false),
                          onChanged: _saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _zone = value);
                                  }
                                },
                          validator: (value) => value == null || value.isEmpty
                              ? 'Selecciona una zona'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Medio de transporte *'),
                        ),
                        const SizedBox(height: 6),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'vehiculo',
                              label: Text('Vehículo'),
                              icon: Icon(Icons.directions_car_outlined),
                            ),
                            ButtonSegment(
                              value: 'bicicleta',
                              label: Text('Bicicleta'),
                              icon: Icon(Icons.pedal_bike_outlined),
                            ),
                            ButtonSegment(
                              value: 'otro',
                              label: Text('Otro'),
                              icon: Icon(Icons.more_horiz),
                            ),
                          ],
                          selected: {_transport},
                          onSelectionChanged: _saving
                              ? null
                              : (selection) {
                                  final transport = selection.first;
                                  setState(() {
                                    _transport = transport;
                                    if (!_usesVehicle) {
                                      _plateDebounce?.cancel();
                                      _plateCheckPending = false;
                                      _plateAvailable = null;
                                    }
                                  });
                                  if (transport == 'vehiculo') {
                                    _schedulePlateCheck(_plateController.text);
                                  }
                                },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('recolector_experience_field'),
                          controller: _experienceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Años de experiencia *',
                          ),
                          validator: (value) {
                            final experience =
                                int.tryParse(value?.trim() ?? '');
                            if (experience == null ||
                                experience < 0 ||
                                experience > 50) {
                              return 'Ingresa un número entre 0 y 50';
                            }
                            return null;
                          },
                        ),
                        if (_usesVehicle) ...[
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const Key('recolector_plate_field'),
                            controller: _plateController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Placa *',
                              suffixIcon: _plateCheckPending
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : _plateAvailable == true
                                      ? const Icon(
                                          Icons.check_circle_outline,
                                          color: AppColors.success,
                                        )
                                      : null,
                            ),
                            onChanged: _schedulePlateCheck,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa la placa';
                              }
                              if (_plateAvailable == false) {
                                return 'Esta placa ya está registrada en otro recolector activo';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('recolector_brand_field'),
                            controller: _brandController,
                            decoration:
                                const InputDecoration(labelText: 'Marca *'),
                            validator: (value) => _usesVehicle &&
                                    (value == null || value.trim().isEmpty)
                                ? 'Ingresa la marca del vehículo'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('recolector_capacity_field'),
                            controller: _capacityController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Capacidad (kg) *',
                            ),
                            validator: (value) {
                              final capacity =
                                  double.tryParse(value?.trim() ?? '');
                              if (_usesVehicle &&
                                  (capacity == null || capacity <= 0)) {
                                return 'Ingresa una capacidad mayor que cero';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Guardando...' : 'Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
