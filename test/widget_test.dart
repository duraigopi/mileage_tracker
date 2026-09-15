import 'package:flutter_test/flutter_test.dart';

import 'package:mileage_app/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Bike Tracker'), findsOneWidget);
  });
}
