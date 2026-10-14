import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/widgets/host_range_input.dart';
import 'host_management_test.dart' as fixture;
import 'package:home_share/data/models/room_model.dart';

void main() {
  testWidgets('Typing expands slider and dragging updates both fields', (
    tester,
  ) async {
    var values = const RangeValues(2000000, 5000000);
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Form(
              key: form,
              child: HostRangeInput(
                label: 'Giá thuê',
                unit: 'đ',
                values: values,
                sliderMax: 20000000,
                onChanged: (next) => setState(() => values = next),
              ),
            ),
          ),
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), '45000000');
    await tester.pump();
    expect(values.end, 45000000);
    expect(tester.widget<RangeSlider>(find.byType(RangeSlider)).max, 45000000);
    tester.widget<RangeSlider>(find.byType(RangeSlider)).onChanged!(
      const RangeValues(40000000, 42000000),
    );
    await tester.pump();
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller!.text,
      '40000000',
    );
    expect(
      tester.widget<TextFormField>(fields.at(1)).controller!.text,
      '42000000',
    );
    await tester.enterText(fields.at(1), '30000000');
    expect(form.currentState!.validate(), isFalse);
  });
  test('Area range survives storage and legacy single area stays readable', () {
    final room = RoomModel.fromMap({
      ...fixture.makeRoom('A1').toMap(),
      'area': 40,
      'minArea': 40,
      'maxArea': 45,
    }, 'A1');
    final restored = RoomModel.fromMap(room.toMap(), room.id);
    expect(restored.minArea, 40);
    expect(restored.maxArea, 45);
    expect(restored.areaLabel, '40.0–45.0 m²');
    expect(fixture.makeRoom('old').area, 25);
  });
}
