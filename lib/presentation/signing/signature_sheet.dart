import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/signature_type.dart';
import '../../domain/electronic_signature_service.dart';
import 'signature_pad.dart';

/// Abre el formulario para firmar la página actual.
Future<SignatureDraft?> showSignatureSheet(
  BuildContext context, {
  required int pageNumber,
  String? initialSignerName,
}) {
  return showModalBottomSheet<SignatureDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HermesColors.of(context).panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
    ),
    builder: (context) => _SignatureForm(
      pageNumber: pageNumber,
      initialSignerName: initialSignerName,
    ),
  );
}

class _SignatureForm extends StatefulWidget {
  const _SignatureForm({
    required this.pageNumber,
    this.initialSignerName,
  });

  final int pageNumber;
  final String? initialSignerName;

  @override
  State<_SignatureForm> createState() => _SignatureFormState();
}

class _SignatureFormState extends State<_SignatureForm> {
  static const _service = ElectronicSignatureService();

  late final TextEditingController _nameController;
  late final TextEditingController _typedController;
  late final TextEditingController _reasonController;

  SignatureType _type = SignatureType.typed;
  List<List<List<double>>> _inkStrokes = const [];
  String? _validationError;
  String _lastAutoTyped = '';
  bool _typedDirty = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final initial =
        _service.normalizePersonText(widget.initialSignerName ?? '');
    _nameController = TextEditingController(text: initial);
    _typedController = TextEditingController(text: initial);
    _reasonController = TextEditingController();
    _lastAutoTyped = initial;
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

  @override
  void dispose() {
    _nameController.removeListener(_syncTypedFromName);
    _typedController.removeListener(_onTypedChanged);
    _nameController.dispose();
    _typedController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  SignatureDraft get _draft => SignatureDraft(
        type: _type,
        signerName: _service.normalizePersonText(_nameController.text),
        typedText: _service.normalizePersonText(_typedController.text),
        inkStrokes: _inkStrokes,
        reason: _service.normalizeOptionalText(_reasonController.text),
      );

  void _submit() {
    if (_submitting) return;
    setState(() {
      _validationError = null;
      _submitting = true;
    });
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
    final colors = HermesColors.of(context);
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
                    color: AppColors.obsidianAccent,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Firma electrónica simple, local y offline. '
              'No sustituye una firma cualificada con certificado.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
            ),
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
                    return AppColors.obsidianBackground;
                  }
                  return colors.text;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.obsidianAccent;
                  }
                  return colors.surface;
                }),
              ),
            ),
            const SizedBox(height: 16),
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
            if (_validationError != null) ...[
              const SizedBox(height: 12),
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
                      backgroundColor: AppColors.obsidianAccent,
                      foregroundColor: AppColors.obsidianBackground,
                      disabledBackgroundColor:
                          AppColors.obsidianAccent.withValues(alpha: 0.5),
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
