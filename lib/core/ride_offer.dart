enum PlatformType {
  uber,
  nineNine,
  ifood,
  rappi,
  lalamove,
  loggi,
  nineNineDelivery,
  borzo,
  unknown,
}

enum RideCategory {
  uberX,
  comfort,
  black,
  priority,
  pop,
  plus,
  moto,
  delivery,
  unknown,
}

enum OfferType { standard, negotiates, unknown }

enum PaymentType { app, cash, pix, unknown }

class RideOffer {
  final PlatformType platform;
  final RideCategory category;
  final OfferType offerType;
  final PaymentType paymentType;
  final double value;
  final String origin;
  final String destination;
  final double pickupDistanceKm;
  final double tripDistanceKm;
  final int pickupTimeMin;
  final int tripTimeMin;
  final int stops;

  const RideOffer({
    required this.platform,
    required this.category,
    required this.offerType,
    required this.paymentType,
    required this.value,
    required this.origin,
    required this.destination,
    required this.pickupDistanceKm,
    required this.tripDistanceKm,
    required this.pickupTimeMin,
    required this.tripTimeMin,
    this.stops = 0,
  });

  double get totalDistanceKm => pickupDistanceKm + tripDistanceKm;
  int get totalTimeMin => pickupTimeMin + tripTimeMin;

  double get reaisPerKm =>
      totalDistanceKm > 0 ? value / totalDistanceKm : 0;

  double get reaisPerHour =>
      totalTimeMin > 0 ? value / (totalTimeMin / 60) : 0;
}
