import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/theme/app_theme.dart';
import 'package:minimal_pdf/l10n/app_localizations.dart';
import 'package:minimal_pdf/presentation/reader/widgets/reader_sidebar.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.ebony,
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );
  }

  testWidgets('sidebar muestra navegación, página actual y CTAs vacíos',
      (tester) async {
    var openedTools = false;
    var startedSigning = false;
    var addedBookmark = false;

    await tester.pumpWidget(
      wrap(
        ReaderSidebar(
          visible: true,
          pagesCount: 5,
          currentPage: 2,
          bookmarks: const [],
          annotations: const [],
          signatures: const [],
          onClose: () {},
          onOpenPage: (_) {},
          onDeleteBookmark: (_) {},
          onOpenAnnotationTools: () => openedTools = true,
          onStartSigning: () => startedSigning = true,
          onAddBookmark: () => addedBookmark = true,
        ),
      ),
    );

    expect(find.text('Navegación'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('Página 2'), findsWidgets);
    expect(find.text('Actual'), findsOneWidget);

    await tester.tap(find.text('Marcadores'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aún no hay marcadores'), findsOneWidget);
    expect(find.text('Marcar página'), findsOneWidget);
    await tester.tap(find.text('Marcar página'));
    await tester.pump();
    expect(addedBookmark, isTrue);

    await tester.tap(find.text('Anotaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir herramientas'), findsOneWidget);
    await tester.tap(find.text('Abrir herramientas'));
    await tester.pump();
    expect(openedTools, isTrue);

    await tester.tap(find.text('Firmas'));
    await tester.pumpAndSettle();
    expect(find.text('Firmar documento'), findsOneWidget);
    await tester.tap(find.text('Firmar documento'));
    await tester.pump();
    expect(startedSigning, isTrue);
  });
}
