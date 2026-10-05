import 'package:flutter_test/flutter_test.dart';
import 'package:acessor_motorista/core/offer_analyzer.dart';
import 'package:acessor_motorista/core/ride_offer.dart';

void main() {
  test('calcula distancia e indicadores da oferta', () {
    const offer = RideOffer(
      platform: PlatformType.uber,
      category: RideCategory.uberX,
      offerType: OfferType.standard,
      paymentType: PaymentType.app,
      value: 60,
      origin: 'Origem',
      destination: 'Destino',
      pickupDistanceKm: 3,
      tripDistanceKm: 21,
      pickupTimeMin: 9,
      tripTimeMin: 54,
    );

    expect(offer.totalDistanceKm, 24);
    expect(offer.totalTimeMin, 63);
    expect(offer.reaisPerKm, 2.5);
    expect(offer.reaisPerHour, closeTo(57.14, 0.01));
  });

  test('oferta fica ruim quando quebra uma regra', () {
    const offer = RideOffer(
      platform: PlatformType.uber,
      category: RideCategory.uberX,
      offerType: OfferType.standard,
      paymentType: PaymentType.app,
      value: 40,
      origin: 'Origem',
      destination: 'Destino',
      pickupDistanceKm: 3,
      tripDistanceKm: 21,
      pickupTimeMin: 9,
      tripTimeMin: 54,
    );

    const rule = CategoryRule(
      minValue: 50,
      maxDistanceKm: 25,
      maxTimeMin: 70,
      minReaisPerKm: 2,
      minReaisPerHour: 45,
    );

    final result = const OfferAnalyzer().analyze(offer, rule);

    expect(result.accepted, isFalse);
    expect(result.reasons, contains('Valor abaixo do minimo'));
  });
}
