import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_portfolio/app.dart';
import 'package:flutter_portfolio/providers/app_settings.dart';
import 'package:flutter_portfolio/providers/network_monitor_provider.dart';
import 'package:flutter_portfolio/routes.dart';

Widget _buildApp({
  AppSettings? settings,
  NetworkMonitorProvider? monitor,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => settings ?? AppSettings()),
      ChangeNotifierProvider(create: (_) => monitor ?? NetworkMonitorProvider()),
    ],
    child: const PortfolioApp(),
  );
}

void main() {
  testWidgets('home dashboard shows compilation header and activities',
      (tester) async {
    final settings = AppSettings()..setDisplayName('Alex');

    await tester.pumpWidget(_buildApp(settings: settings));

    expect(find.text('Home Dashboard'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Activities Compilation'), findsOneWidget);
    expect(find.text('Counter Activity'), findsOneWidget);
    expect(find.text('Notes Activity'), findsOneWidget);
    expect(find.text('Network Monitor'), findsOneWidget);
    expect(find.text('Activity 1'), findsOneWidget);
    expect(find.text('Activity 2'), findsOneWidget);
    expect(find.text('Activity 3'), findsOneWidget);
  });

  testWidgets('navigation route to Activity 1 Counter operates increment/decrement',
      (tester) async {
    await tester.pumpWidget(_buildApp());

    await tester.tap(find.text('Counter Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Activity 1: Counter Activity'), findsOneWidget);
    expect(find.text('Activities Compilation • Activity 1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.text('Increment'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // Navigate back to compilation dashboard
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Home Dashboard'), findsOneWidget);
  });

  testWidgets('adding a note persists across back navigation and increments counter',
      (tester) async {
    await tester.pumpWidget(_buildApp());

    // 1. Open Notes Activity (Activity 2)
    await tester.tap(find.text('Notes Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Activity 2: Notes Activity'), findsOneWidget);

    // 2. Add a new note
    await tester.enterText(
        find.byType(TextField), 'Study for Flutter exam');
    await tester.tap(find.text('Add note'));
    await tester.pump();

    expect(find.text('Study for Flutter exam'), findsOneWidget);

    // 3. Navigate back to Home Dashboard
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Home Dashboard'), findsOneWidget);

    // 4. Re-open Notes Activity: Note is STILL there!
    await tester.tap(find.text('Notes Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Study for Flutter exam'), findsOneWidget);

    // 5. Navigate back to Home Dashboard
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 6. Open Counter Activity (Activity 1): Counter should reflect the increment!
    await tester.tap(find.text('Counter Activity'));
    await tester.pumpAndSettle();

    expect(find.text('Activity 1: Counter Activity'), findsOneWidget);
    // Count should be 1 because adding a note incremented it!
    expect(find.text('1'), findsOneWidget);
    // Verify notes list is NOT displayed on the Counter screen
    expect(find.text('Notes from Activity 2'), findsNothing);
  });

  testWidgets('navigates to settings screen and shows current profile name',
      (tester) async {
    final settings = AppSettings()..setDisplayName('Morgan');
    await tester.pumpWidget(_buildApp(settings: settings));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('User Profile'), findsOneWidget);
    expect(find.text('Current Name: Morgan'), findsOneWidget);
    expect(find.text('Morgan'), findsWidgets);
  });

  testWidgets('updating profile name in settings reflects on home dashboard',
      (tester) async {
    final settings = AppSettings()..setDisplayName('Guest');
    await tester.pumpWidget(_buildApp(settings: settings));

    expect(find.text('Guest'), findsOneWidget);

    // Open Settings
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    // Enter new name and save
    final nameField = find.byType(TextFormField);
    await tester.enterText(nameField, 'Jordan');
    await tester.tap(find.text('Save Name'));
    await tester.pumpAndSettle();

    expect(find.text('Current Name: Jordan'), findsOneWidget);
    expect(find.text('Profile name updated to "Jordan"'), findsOneWidget);

    // Navigate back to Home Dashboard
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Verify Home Dashboard reflects the new profile name
    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text('Guest'), findsNothing);
  });

  testWidgets('validates empty profile name in settings', (tester) async {
    await tester.pumpWidget(_buildApp());

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    final nameField = find.byType(TextFormField);
    await tester.enterText(nameField, '   ');
    await tester.tap(find.text('Save Name'));
    await tester.pump();

    expect(find.text('Please enter a valid profile name'), findsOneWidget);
  });

  testWidgets('toggling dark mode in settings updates theme state',
      (tester) async {
    await tester.pumpWidget(_buildApp());

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Light theme is active'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.text('Dark theme is active'), findsOneWidget);
  });

  testWidgets('onGenerateRoute fallback displays 404 for unknown routes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: AppRoutes.onGenerateRoute,
        initialRoute: '/unknown-route',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Route Not Found'), findsOneWidget);
    expect(find.text('No route defined for "/unknown-route"'), findsOneWidget);
  });
}
