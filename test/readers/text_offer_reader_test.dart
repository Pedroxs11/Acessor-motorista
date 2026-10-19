import 'package:flutter_test/flutter_test.dart';
import 'package:acessor_motorista/core/ride_offer.dart';
import 'package:acessor_motorista/readers/text_offer_reader.dart';

void main() {
  const reader = TextOfferReader();

  test('recognizes the visible UberX offer format', () {
    const text = '''
      UberX Exclusivo
      R\$ 43
      R\$1,72/km aprox.
      4 min (1.1 km)
      Rua Barueri, Jardim Angela, Embu das Artes
      1 h e 5 min (23.9 km)
      Alameda Campinas, 300, Jardim Paulista, São Paulo
      Viagem longa (mais de 45 min)
      Aceitar
    ''';

    final offer = reader.read(text);

    expect(offer, isNotNull);
    expect(offer!.platform, PlatformType.uber);
    expect(offer.category, RideCategory.uberX);
    expect(offer.value, 43);
    expect(offer.pickupTimeMin, 4);
    expect(offer.tripTimeMin, 65);
    expect(offer.pickupDistanceKm, 1.1);
    expect(offer.tripDistanceKm, 23.9);
    expect(offer.totalTimeMin, 69);
    expect(offer.totalDistanceKm, closeTo(25.0, 0.001));
    expect(offer.reaisPerKm, closeTo(1.72, 0.01));
    expect(offer.reaisPerHour, closeTo(37.39, 0.1));
  });

  test('does not confuse hourly duration with minutes only', () {
    const text = 'UberX R\$ 43 4 min (1.1 km) 1 h e 5 min (23.9 km)';
    final offer = reader.read(text);

    expect(offer, isNotNull);
    expect(offer!.tripTimeMin, 65);
  });
}
