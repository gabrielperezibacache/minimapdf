import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_pdf/core/constants/app_constants.dart';
import 'package:minimal_pdf/core/database/app_database.dart';
import 'package:minimal_pdf/core/database/library_database.dart';
import 'package:minimal_pdf/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase appDatabase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    appDatabase = AppDatabase(
      customFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    await appDatabase.open();
  });

  tearDown(() async {
    await appDatabase.close();
  });

  testWidgets('Minimal PDF muestra la pantalla base de biblioteca',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MinimalPdfApp(
        appDatabase: appDatabase,
        libraryDatabase: LibraryDatabase(appDatabase),
      ),
    );

    expect(find.text(AppConstants.appName), findsWidgets);
    expect(find.text(AppConstants.appTagline), findsOneWidget);
    expect(find.text('Hermes Obsidian'), findsOneWidget);
  });
}
