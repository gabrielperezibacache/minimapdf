import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Pantalla de bienvenida: solo la primera apertura tras instalar.
///
/// Explica el valor de Minimal PDF y sus funciones principales.
/// Al continuar o omitir invoca [onFinished] (el root marca el flag y
/// muestra la biblioteca).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  static const List<_WelcomePageData> _pages = [
    _WelcomePageData(
      icon: Icons.menu_book_outlined,
      title: 'Tu biblioteca, solo tuya',
      body:
          'Importa PDFs desde el dispositivo, organízalos en colecciones y '
          'edita título, autor y etiquetas. Todo queda en local: sin nube, '
          'sin cuentas y sin sincronización forzada.',
    ),
    _WelcomePageData(
      icon: Icons.chrome_reader_mode_outlined,
      title: 'Lectura rápida y cómoda',
      body:
          'Desplazamiento continuo o página a página, filtro Hermes Obsidian '
          'para reducir el cansancio visual, progreso automático, marcadores '
          'en bronce y notas flotantes en cada página.',
    ),
    _WelcomePageData(
      icon: Icons.download_outlined,
      title: 'Descargas con privacidad',
      body:
          'Pega una URL directa o usa el mini-navegador con «Capturar PDF». '
          'Sin telemetría, sin anuncios y sin suscripciones: un lector '
          'ultraligero pensado para leer, no para rastrearte.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() => widget.onFinished();

  void _next() {
    if (_pageIndex >= _pages.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isLast = _pageIndex >= _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConstants.appName,
                          style: textTheme.headlineMedium?.copyWith(
                            color: colors.accent,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppConstants.appTagline,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Omitir',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Text(
                  key: ValueKey<int>(_pageIndex == 0 ? 0 : 1),
                  _pageIndex == 0
                      ? 'Bienvenido a una lectura offline, privada y sin ruido.'
                      : 'Así funciona Minimal PDF',
                  style: textTheme.titleLarge?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _pageIndex = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _WelcomePage(page: page, accent: colors.accent);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final active = index == _pageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 3,
                        width: active ? 28 : 10,
                        decoration: BoxDecoration(
                          color: active ? colors.accent : colors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: colors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(isLast ? 'Empezar a leer' : 'Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePageData {
  const _WelcomePageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.page,
    required this.accent,
  });

  final _WelcomePageData page;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = HermesColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey<String>(page.title),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(page.icon, color: accent, size: 28),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            page.title,
            style: textTheme.headlineSmall?.copyWith(
              color: colors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.body,
            style: textTheme.bodyLarge?.copyWith(
              color: colors.textMuted,
              height: 1.5,
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: accent, width: 2),
              ),
              color: colors.panel,
            ),
            child: Text(
              'Pago único · 100% offline · Cero analíticas',
              style: textTheme.labelLarge?.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}
