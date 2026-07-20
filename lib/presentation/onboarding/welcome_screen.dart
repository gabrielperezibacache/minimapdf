import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

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
  bool _finished = false;
  bool _disposed = false;

  List<_WelcomePageData> _pagesFor(AppLocalizations l10n) => [
        _WelcomePageData(
          icon: Icons.shield_outlined,
          title: l10n.welcomePage1Title,
          body: l10n.welcomePage1Body,
          highlight: l10n.welcomePage1Highlight,
        ),
        _WelcomePageData(
          icon: Icons.menu_book_outlined,
          title: l10n.welcomePage2Title,
          body: l10n.welcomePage2Body,
          highlight: l10n.welcomePage2Highlight,
        ),
        _WelcomePageData(
          icon: Icons.chrome_reader_mode_outlined,
          title: l10n.welcomePage3Title,
          body: l10n.welcomePage3Body,
          highlight: l10n.welcomePage3Highlight,
        ),
      ];

  @override
  void dispose() {
    _disposed = true;
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    if (_finished || _disposed) return;
    _finished = true;
    widget.onFinished();
  }

  void _next(int pageCount) {
    if (_pageIndex >= pageCount - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_pageIndex <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final pages = _pagesFor(l10n);
    final isFirst = _pageIndex == 0;
    final isLast = _pageIndex >= pages.length - 1;
    final brightness = Theme.of(context).brightness;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
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
                            l10n.appTagline,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      TextButton(
                        onPressed: _finished ? null : _finish,
                        child: Text(
                          l10n.skip,
                          style: TextStyle(color: colors.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: Text(
                    key: ValueKey<bool>(isFirst),
                    isFirst
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
                  itemCount: pages.length,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    if (_disposed || _finished) return;
                    setState(() => _pageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return _WelcomePage(
                      page: pages[index],
                      accent: colors.accent,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  children: [
                    Semantics(
                      label: l10n.welcomeStep(_pageIndex + 1, pages.length),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(pages.length, (index) {
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
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (!isFirst) ...[
                          SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _finished ? null : _back,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.text,
                                side: BorderSide(color: colors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: Text(l10n.back),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed:
                                  _finished ? null : () => _next(pages.length),
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.accent,
                                foregroundColor: colors.background,
                                disabledBackgroundColor:
                                    colors.accent.withValues(alpha: 0.45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: Text(
                                isLast ? l10n.welcomeStart : l10n.welcomeContinue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    required this.highlight,
  });

  final IconData icon;
  final String title;
  final String body;
  final String highlight;
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
    final colors = AppPalette.of(context);
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 8),
            child: IntrinsicHeight(
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
                        opacity: value.clamp(0.0, 1.0),
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
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 24),
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
                      page.highlight,
                      style: textTheme.labelLarge?.copyWith(color: accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
