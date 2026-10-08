import 'package:fl_clash/widgets/boot_text.dart';
import 'package:fl_clash/widgets/ignition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _host({required bool active}) {
  return MaterialApp(
    home: Ignition(
      active: active,
      origin: Alignment.bottomRight,
      child: const Center(child: BootText('12.5 MB/s')),
    ),
  );
}

void main() {
  test('masks letters and digits but keeps the punctuation', () {
    expect(BootText.mask('12.5 MB/s'), '--.- --/-');
    expect(BootText.mask('↑ 0 B/s'), '↑ - -/-');
  });

  test('decodes from the left and leaves resolved glyphs alone', () {
    expect(BootText.decode('12.5 MB/s', 1, 3), '12.5 MB/s');
    final half = BootText.decode('12.5 MB/s', 0.5, 3);
    expect(half.substring(0, 4), '12.5');
    expect(half.length, '12.5 MB/s'.length);
    expect(half[4], ' ');
    expect(half, isNot('12.5 MB/s'));
  });

  testWidgets('is a plain Text outside an ignition', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BootText('12.5 MB/s')));
    expect(find.text('12.5 MB/s'), findsOneWidget);
  });

  testWidgets('stays masked until lit, then decodes into the real text', (
    tester,
  ) async {
    await tester.pumpWidget(_host(active: false));
    expect(find.text('--.- --/-'), findsOneWidget);

    await tester.pumpWidget(_host(active: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('12.5 MB/s'), findsNothing);
    expect(find.text('--.- --/-'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('12.5 MB/s'), findsOneWidget);
  });

  testWidgets('masks again once stopped', (tester) async {
    await tester.pumpWidget(_host(active: true));
    expect(find.text('12.5 MB/s'), findsOneWidget);

    await tester.pumpWidget(_host(active: false));
    await tester.pumpAndSettle();
    expect(find.text('--.- --/-'), findsOneWidget);
  });
}
