import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/admin_auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/centro_acopio_entity.dart';
import '../../../../domain/repositories/centro_acopio_repository.dart';
import '../../../widgets/phone_input_field.dart';

class CentroFormDialog extends ConsumerStatefulWidget {
  const CentroFormDialog({
    required this.repository,
    this.centro,
    super.key,
  });

  final CentroAcopioRepository repository;
  final CentroAcopioEntity? centro;

  @override
  ConsumerState<CentroFormDialog> createState() => _CentroFormDialogState();
}

class _CentroFormDialogState extends ConsumerState<CentroFormDialog> {
  static const List<({String id, String label})> _materials = [
    (id: 'plastico', label: 'Plástico'),
    (id: 'vidrio', label: 'Vidrio'),
    (id: 'metal', label: 'Metal'),
    (id: 'papel', label: 'Papel/Cartón'),
    (id: 'organico', label: 'Orgánico'),
    (id: 'textil', label: 'Textil'),
    (id: 'electronico', label: 'Electrónico'),
    (id: 'otro', label: 'Otro'),
  ];
  static const List<String> _zones = [
    'Zona Norte',
    'Zona Sur',
    'Zona Este',
    'Zona Oeste',
    'Centro',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _managerController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _scheduleController;
  late final TextEditingController _capacityController;
  late String _zone;
  late Set<String> _selectedMaterials;
  bool _saving = false;
  bool _showMaterialsError = false;

  @override
  void initState() {
    super.initState();
    final center = widget.centro;
    _nameController = TextEditingController(text: center?.nombre ?? '');
    _managerController = TextEditingController(text: center?.responsable ?? '');
    _phoneController = TextEditingController(text: center?.telefono ?? '');
    _addressController = TextEditingController(text: center?.direccion ?? '');
    _scheduleController = TextEditingController(text: center?.horario ?? '');
    _capacityController = TextEditingController(
      text: center?.capacidadMaxima.toString() ?? '',
    );
    _zone = center?.zona?.isNotEmpty == true ? center!.zona! : _zones.first;
    _selectedMaterials = center?.materialesAceptados.toSet() ?? <String>{};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _managerController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _scheduleController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!ref.read(adminPermissionsProvider).canManageCentros) {
      _showError('Sin permisos');
      return;
    }
    final valid = _formKey.currentState?.validate() ?? false;
    setState(() => _showMaterialsError = _selectedMaterials.isEmpty);
    if (!valid || _selectedMaterials.isEmpty || _saving) return;

    final previous = widget.centro;
    setState(() => _saving = true);
    try {
      if (!ref.read(adminPermissionsProvider).canManageCentros) {
        _showError('Sin permisos');
        return;
      }
      if (previous == null) {
        await widget.repository.create(
          CentroAcopioEntity(
            id: '',
            nombre: _nameController.text.trim(),
            responsable: _managerController.text.trim(),
            telefono: _phoneController.text.trim(),
            direccion: _addressController.text.trim(),
            materialesAceptados: _selectedMaterials.toList(growable: false),
            capacidadMaxima: double.parse(_capacityController.text.trim()),
            estadoActivo: true,
            kilosComprometidos: 0,
            totalOfertas: 0,
            horario: _scheduleController.text.trim(),
            zona: _zone,
          ),
        );
      } else {
        await widget.repository.update(previous.id, {
          'nombre_empresa': _nameController.text.trim(),
          'nombre': _managerController.text.trim(),
          'telefono': _phoneController.text.trim(),
          'direccion_fija': _addressController.text.trim(),
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } on CentroAcopioCapacityBelowCommitted catch (error) {
      _showError(error.toString());
    } on StateError catch (error) {
      _showError(error.message.toString());
    } catch (error, stackTrace) {
      debugPrint('No se pudo guardar el centro de acopio: $error\n$stackTrace');
      _showError(
          'No se pudo guardar el centro. Revisa los datos e intenta otra vez.');
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
    final existingZone = _zones.contains(_zone) ? _zones : [_zone, ..._zones];
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
                      widget.centro == null
                          ? 'Nuevo centro de acopio'
                          : 'Editar centro de acopio',
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
                        _requiredTextField(
                          controller: _nameController,
                          label: 'Nombre *',
                          key: const Key('centro_name_field'),
                        ),
                        const SizedBox(height: 14),
                        _requiredTextField(
                          controller: _managerController,
                          label: 'Responsable *',
                          key: const Key('centro_manager_field'),
                        ),
                        const SizedBox(height: 14),
                        PhoneInputField(
                          key: const Key('centro_phone_field'),
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
                        _requiredTextField(
                          controller: _addressController,
                          label: 'Dirección *',
                          key: const Key('centro_address_field'),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _zone,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Zona *'),
                          items: existingZone
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
                        TextFormField(
                          key: const Key('centro_schedule_field'),
                          controller: _scheduleController,
                          decoration: const InputDecoration(
                            labelText: 'Horario *',
                            hintText: 'Ej: Lunes a Viernes 8:00-18:00',
                          ),
                          validator: _requiredValidator('Ingresa el horario'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('centro_capacity_field'),
                          controller: _capacityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Capacidad máxima (kg) *',
                          ),
                          validator: (value) {
                            final capacity =
                                double.tryParse(value?.trim() ?? '');
                            if (capacity == null || capacity <= 0) {
                              return 'Ingresa una capacidad mayor que cero';
                            }
                            if (widget.centro != null &&
                                capacity < widget.centro!.kilosComprometidos) {
                              return 'No puede ser menor que los ${widget.centro!.kilosComprometidos} kg comprometidos';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Materiales aceptados *',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _materials.map((material) {
                            final selected =
                                _selectedMaterials.contains(material.id);
                            final color = _materialColor(material.id);
                            return FilterChip(
                              key: Key('material_${material.id}'),
                              label: Text(material.label),
                              selected: selected,
                              selectedColor: color.withOpacity(0.18),
                              checkmarkColor: color,
                              labelStyle: TextStyle(
                                color: selected ? color : AppColors.textPrimary,
                              ),
                              onSelected: _saving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        if (value) {
                                          _selectedMaterials.add(material.id);
                                        } else {
                                          _selectedMaterials
                                              .remove(material.id);
                                        }
                                        _showMaterialsError = false;
                                      });
                                    },
                            );
                          }).toList(growable: false),
                        ),
                        if (_showMaterialsError) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Selecciona al menos un material',
                            style: TextStyle(color: AppColors.error),
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

  TextFormField _requiredTextField({
    required TextEditingController controller,
    required String label,
    required Key key,
    int maxLines = 1,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: _requiredValidator(
          'Ingresa ${label.replaceAll(' *', '').toLowerCase()}'),
    );
  }

  FormFieldValidator<String> _requiredValidator(String message) => (value) {
        return value == null || value.trim().isEmpty ? message : null;
      };
}

Color _materialColor(String material) => switch (material) {
      'plastico' => Colors.blue,
      'vidrio' => Colors.lightGreen,
      'metal' => Colors.blueGrey,
      'papel' => Colors.brown,
      'organico' => AppColors.primaryDark,
      'textil' => Colors.deepPurple,
      'electronico' => AppColors.warning,
      _ => Colors.grey.shade800,
    };
