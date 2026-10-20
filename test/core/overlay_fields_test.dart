import 'package:flutter_test/flutter_test.dart';
import 'package:acessor_motorista/core/overlay_fields.dart';

void main() {
  test('defaults to showing every supported field', () {
    final fields = const OverlayFields();

    expect(fields.toMap().values.every((visible) => visible), isTrue);
  });

  test('restores hidden fields while defaulting missing keys to visible', () {
    final fields = OverlayFields.fromMap({
      'value': false,
      'time': false,
    });

    expect(fields.value, isFalse);
    expect(fields.time, isFalse);
    expect(fields.perKm, isTrue);
    expect(fields.destination, isTrue);
  });

  test('copies one preference without changing the others', () {
    final fields = const OverlayFields().copyWith(perKm: false);

    expect(fields.perKm, isFalse);
    expect(fields.value, isTrue);
    expect(fields.origin, isTrue);
  });

  test('serializes and restores the complete preference set', () {
    final original = const OverlayFields().copyWith(
      value: false,
      category: false,
      destination: false,
    );
    final restored = OverlayFields.fromMap(original.toMap());

    expect(restored.toMap(), original.toMap());
  });
}
