import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/signature_type.dart';
import '../../domain/electronic_signature_service.dart';
import 'signature_pad.dart';

/// Abre el formulario para firmar la página actual.
Future<SignatureDraft?> showSignatureSheet(
  BuildContext context, {
  required int pageNumber,
}) {
  return showModalBottomSheet<SignatureDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HermesColors.of(context).panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
    ),
    builder: (context) => _SignatureForm(pageNumber: pageNumber),
  );
}

class _SignatureForm extends StatefulWidget {
  const _SignatureForm({required this.pageNumber});

  final int pageNumber;

  @override
  State<_SignatureForm> createState() => _SignatureFormState();
}

class _SignatureFormState extends State<_SignatureForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _typedController;
  late final TextEditingController _reasonController;
  final GlobalKey<SignaturePadState> _padKey = GlobalKey<SignaturePadState>();

  SignatureType _type = SignatureType.typed;
  List<List<List<double>>> _inkStrokes = const [];
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _typedController = TextEditingController();
    _reasonController = TextEditingController();
    _nameController.addListener(_syncTypedFromName);
    _typedController.addListener(_onTypedChanged);
  }

  void _onTypedChanged() {
    if (mounted) setState(() {});
  }

  void _syncTypedFromName() {
    if (_type != SignatureType.typed) return;
    if (_typedController.text.trim().isEmpty ||
        _typedController.text == _lastAutoTyped) {
      final value = _nameController.text;
      _lastAutoTyped = value;
      _typedController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  String _lastAutoTyped = '';

  @override
  void dispose() {
    _nameController.removeListener(_syncTypedFromName);
    _typedController.removeListener(_onTypedChanged);
    _nameController.dispose();
    _typedController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _validationError = null);
    final draft = SignatureDraft(
      type: _type,
      signerName: _nameController.text,
      typedText: _typedController.text,
      inkStrokes: _inkStrokes,
      reason: _reasonController.text,
    );

    try {
      // Validación previa con el servicio de dominio (bookId/page dummy OK
      // salvo pageNumber; usamos page real y bookId=1 solo para validar forma).
      const ElectronicSignatureService().signDocument(
        bookId: 1,
        pageNumber: widget.pageNumber,
        draft: draft,
      );
      Navigator.of(context).pop(draft);
    } on SignatureValidationException catch (error) {
      setState(() => _validationError = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
              'Firma electrónica simple, local y offline.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<SignatureType>(
              segments: const [
                ButtonSegment(
                  value: SignatureType.typed,
                  label: Text('Mecanografiada'),
                  icon: Icon(Icons.text_fields, size: 18),
                ),
                ButtonSegment(
                  value: SignatureType.drawn,
                  label: Text('Dibujada'),
                  icon: Icon(Icons.gesture, size: 18),
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
              decoration: const InputDecoration(
                labelText: 'Nombre del firmante',
                hintText: 'Nombre y apellidos',
              ),
            ),
            const SizedBox(height: 12),
            if (_type == SignatureType.typed) ...[
              TextField(
                controller: _typedController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Texto de la firma',
                  hintText: 'Cómo se verá la rúbrica',
                ),
              ),
              const SizedBox(height: 12),
              Container(
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
                key: _padKey,
                onStrokesChanged: (strokes) {
                  setState(() => _inkStrokes = strokes);
                },
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'p. ej. Conformidad, autorización…',
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
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.obsidianAccent,
                      foregroundColor: AppColors.obsidianBackground,
                    ),
                    child: const Text('Firmar'),
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
