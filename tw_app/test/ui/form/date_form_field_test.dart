import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tw_app/ui/form/date_form_field.dart';

void main() {
  group('DateFormField', () {
    testWidgets('uses localized short dates for initial, changed, and reset values', (
      tester,
    ) async {
      final key = GlobalKey<FormFieldState<DateTime>>();
      final initial = DateTime(2026, 11, 14);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateFormField(
              key: key,
              initialValue: initial,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            ),
          ),
        ),
      );
      final field = find.descendant(of: find.byKey(key), matching: find.byType(TextField));
      final localizations = MaterialLocalizations.of(tester.element(field));
      String text() => tester.widget<TextField>(field).controller!.text;
      expect(text(), equals(localizations.formatShortDate(initial)));

      final selected = DateTime(2026, 12, 5);
      key.currentState!.didChange(selected);
      await tester.pump();
      expect(text(), equals(localizations.formatShortDate(selected)));

      key.currentState!.reset();
      await tester.pump();
      expect(text(), equals(localizations.formatShortDate(initial)));
    });

    testWidgets('keeps an unset date blank', (tester) async {
      final key = GlobalKey<FormFieldState<DateTime>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateFormField(key: key, firstDate: DateTime(1900), lastDate: DateTime(2100)),
          ),
        ),
      );
      final field = find.descendant(of: find.byKey(key), matching: find.byType(TextField));
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);

      key.currentState!.didChange(DateTime(2026, 11, 14));
      await tester.pump();
      key.currentState!.reset();
      await tester.pump();

      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    });
  });
}
