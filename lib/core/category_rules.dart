import 'offer_analyzer.dart';
import 'ride_offer.dart';

/// Regras iniciais por categoria. Serao configuraveis pelo motorista na UI.
class DefaultCategoryRules {
  static const uberX = CategoryRule(
    minValue: 0,
    maxDistanceKm: 30,
    maxTimeMin: 90,
    minReaisPerKm: 2,
    minReaisPerHour: 40,
  );

  static const comfort = CategoryRule(
    minValue: 0,
    maxDistanceKm: 35,
    maxTimeMin: 100,
    minReaisPerKm: 2.2,
    minReaisPerHour: 45,
  );

  static const black = CategoryRule(
    minValue: 0,
    maxDistanceKm: 40,
    maxTimeMin: 120,
    minReaisPerKm: 2.5,
    minReaisPerHour: 55,
  );

  static CategoryRule forCategory(RideCategory category) {
    switch (category) {
      case RideCategory.comfort:
        return comfort;
      case RideCategory.black:
        return black;
      case RideCategory.uberX:
      default:
        return uberX;
    }
  }
}
