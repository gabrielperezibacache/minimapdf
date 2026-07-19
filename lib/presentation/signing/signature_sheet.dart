import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/signature_role.dart';
import '../../data/models/signature_template.dart';
import '../../data/models/signature_type.dart';
import '../../domain/electronic_signature_service.dart';
import 'signature_pad.dart';

/// Abre el formulario para firmar la página actual.
Future<SignatureDraft?> showSignatureSheet(
  BuildContext context, {
  required int pageNumber,
  String? initialSignerName,
  SignatureRole? initialRole,
  double? initialOffsetX,
  double? initialOffsetY,
  List<SignatureTemplate> templates = const [],
}) {
  return showModalBottomSheet<SignatureDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppPalette.of(context).panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
    ),
    builder: (context) => _SignatureForm(
      pageNumber: pageNumber,
      initialSignerName: initialSignerName,
      initialRole: initialRole ?? SignatureRole.signer,
      initialOffsetX: initialOffsetX,
      initialOffsetY: initialOffsetY,
      templates: templates,
    ),
  );
}

class _SignatureForm extends StatefulWidget {
  const _SignatureForm({
    required this.pageNumber,
    this.initialSignerName,
    required this.initialRole,
    this.initialOffsetX,
    this.initialOffsetY,
    this.templates = const [],
  });

  final int pageNumber;
  final String? initialSignerName;
  final SignatureRole initialRole;
  final double? initialOffsetX;
  final double? initialOffsetY;
  final List<SignatureTemplate> templates;

  @override
  State<_SignatureForm> createState() => _SignatureFormState();
}

class _SignatureFormState extends State<_SignatureForm> {
  static const _service = ElectronicSignatureService();

  late final TextEditingController _nameController;
  late final TextEditingController _typedController;
  late final TextEditingController _reasonController;
  late final TextEditingController _templateNameController;

  SignatureType _type = SignatureType.typed;
  SignatureRole _role = SignatureRole.signer;
  List<List<List<double>>> _inkStrokes = const [];
  String? _validationError;
  String _lastAutoTyped = '';
  bool _typedDirty = false;
  bool _submitting = false;
  bool _saveAsTemplate = false;
  int _padEpoch = 0;

  @override
  void initState() {
    super.initState();
    final initial =
        _service.normalizePersonText(widget.initialSignerName ?? '');
    _nameController = TextEditingController(text: initial);
    _typedController = TextEditingController(text: initial);
    _reasonController = TextEditingController();
    _templateNameController = TextEditingController();
    _lastAutoTyped = initial;
    _role = widget.initialRole;
    _nameController.addListener(_syncTypedFromName);
    _typedController.addListener(_onTypedChanged);
  }

  void _onTypedChanged() {
    if (_typedController.text != _lastAutoTyped) {
      _typedDirty = true;
    }
    if (mounted) setState(() {});
  }

  void _syncTypedFromName() {
    if (_type != SignatureType.typed || _typedDirty) return;
    final value = _nameController.text;
    _lastAutoTyped = value;
    _typedController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _applyTemplate(SignatureTemplate template) {
    setState(() {
      _type = template.type;
      _role = template.role;
      _nameController.text = template.signerName;
      _typedController.text = template.displayText;
      _lastAutoTyped = template.displayText;
      _typedDirty = template.type == SignatureType.typed &&
          template.displayText != template.signerName;
      _inkStrokes = template.inkStrokes;
      _padEpoch++;
      _validationError = null;
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_syncTypedFromName);
    _typedController.removeListener(_onTypedChanged);
    _nameController.dispose();
    _typedController.dispose();
    _reasonController.dispose();
    _templateNameController.dispose();
    super.dispose();
  }

  SignatureDraft get _draft => SignatureDraft(
        type: _type,
        signerName: _service.normalizePersonText(_nameController.text),
        typedText: _service.normalizePersonText(_typedController.text),
        inkStrokes: _inkStrokes,
        reason: _service.normalizeOptionalText(_reasonController.text),
        role: _role,
        offsetX: widget.initialOffsetX,
        offsetY: widget.initialOffsetY,
        saveAsTemplate: _saveAsTemplate,
        templateName: _templateNameController.text,
      );

  void _submit() {
    if (_submitting) return;
    setState(() {
      _validationError = null;
      _submitting = true;
    });
    if (_saveAsTemplate) {
      final templateName =
          _service.normalizePersonText(_templateNameController.text);
      if (templateName.isEmpty) {
        setState(() {
          _validationError = 'Indica un nombre para la plantilla.';
          _submitting = false;
        });
        return;
      }
    }
    final draft = _draft;
    try {
      _service.validateDraft(draft, pageNumber: widget.pageNumber);
      Navigator.of(context).pop(draft);
    } on SignatureValidationException catch (error) {
      setState(() {
        _validationError = error.message;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final narrow = MediaQuery.sizeOf(context).width < 380;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 36, height: 3, color: colors.border),
            ),
            const SizedBox(height: 16),
            Text(
              'Firmar documento · página ${widget.pageNumber}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.ebonyAccent,
                  ),
            ),
            if (widget.initialOffsetX != null) ...[
              const SizedBox(height: 4),
              Text(
                'Zona seleccionada en la página.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
              ),
            ],
            if (widget.templates.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Plantillas',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.textMuted,
                    ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.templates.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final template = widget.templates[index];
                    return ActionChip(
                      label: Text(template.name),
                      onPressed: () => _applyTemplate(template),
                      side: BorderSide(color: colors.border),
                      backgroundColor: colors.surface,
                      labelStyle: TextStyle(color: colors.text),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            SegmentedButton<SignatureType>(
              segments: [
                ButtonSegment(
                  value: SignatureType.typed,
                  label: Text(narrow ? 'Texto' : 'Mecanografiada'),
                  icon: const Icon(Icons.text_fields, size: 18),
                ),
                ButtonSegment(
                  value: SignatureType.drawn,
                  label: Text(narrow ? 'Trazo' : 'Dibujada'),
                  icon: const Icon(Icons.gesture, size: 18),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) {
                setState(() {
                  _type = value.first;
                  _validationError = null;
                });
              },
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.ebonyBackground;
                  }
                  return colors.text;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.ebonyAccent;
                  }
                  return colors.surface;
                }),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SignatureRole>(
              key: ValueKey(_role),
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: [
                for (final role in SignatureRole.values)
                  DropdownMenuItem(
                    value: role,
                    child: Text(role.labelEs),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _role = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: ElectronicSignatureService.maxSignerNameLength,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  ElectronicSignatureService.maxSignerNameLength,
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Nombre del firmante',
                hintText: 'Nombre y apellidos',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            if (_type == SignatureType.typed) ...[
              TextField(
                controller: _typedController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: ElectronicSignatureService.maxTypedTextLength,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    ElectronicSignatureService.maxTypedTextLength,
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Texto de la firma',
                  hintText: 'Cómo se verá la rúbrica',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vista previa',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.textMuted,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _typedController.text.trim().isEmpty
                          ? 'Tu firma aparecerá aquí'
                          : _typedController.text.trim(),
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontStyle: FontStyle.italic,
                        fontSize: 28,
                        height: 1.15,
                        letterSpacing: 0.5,
                        color: _typedController.text.trim().isEmpty
                            ? colors.textMuted
                            : colors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              SignaturePad(
                key: ValueKey('pad-$_padEpoch'),
                initialStrokes: _inkStrokes,
                onStrokesChanged: (strokes) {
                  setState(() {
                    _inkStrokes = strokes;
                    _validationError = null;
                  });
                },
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              textInputAction: TextInputAction.done,
              maxLength: ElectronicSignatureService.maxReasonLength,
              onSubmitted: (_) => _submit(),
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  ElectronicSignatureService.maxReasonLength,
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'p. ej. Conformidad, autorización…',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _saveAsTemplate,
              activeColor: AppColors.ebonyAccent,
              title: Text(
                'Guardar como plantilla',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onChanged: (value) {
                setState(() => _saveAsTemplate = value ?? false);
              },
            ),
            if (_saveAsTemplate) ...[
              TextField(
                controller: _templateNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la plantilla',
                  hintText: 'p. ej. Mi rúbrica',
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_validationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.redAccent,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.text,
                      side: BorderSide(color: colors.border),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ebonyAccent,
                      foregroundColor: AppColors.ebonyBackground,
                      disabledBackgroundColor:
                          AppColors.ebonyAccent.withValues(alpha: 0.5),
                    ),
                    child: Text(_submitting ? 'Firmando…' : 'Firmar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
