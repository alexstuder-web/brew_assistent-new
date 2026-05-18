import 'package:flutter_test/flutter_test.dart';
import 'package:brew_genius/main.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('App should start and show entry buttons', (WidgetTester tester) async {
    // We mock the dependencies if necessary, but for a smoke test we can try to just pump the app
    // Note: main() calls Supabase.initialize which might fail in tests
    // So we pump the BrewMateApp directly with fake repositories if possible
    
    await tester.pumpWidget(const BrewMateApp(initialLocale: Locale('de')));
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Currently Brewing'), findsOneWidget);
  });
}
