import 'ride_offer.dart';

class CategoryRule {
  final double? minValue;
  final double? maxDistanceKm;
  final int? maxTimeMin;
  final double? minReaisPerKm;
  final double? minReaisPerHour;
  final double? maxPickupDistanceKm;
  final int? maxPickupTimeMin;

  const CategoryRule({
    this.minValue,
    this.maxDistanceKm,
    this.maxTimeMin,
    this.minReaisPerKm,
    this.minReaisPerHour,
    this.maxPickupDistanceKm,
    this.maxPickupTimeMin,
  });
}

class AnalysisResult {
  final bool accepted;
  final List<String> reasons;

  const AnalysisResult({
    required this.accepted,
    required this.reasons,
  });
}

class OfferAnalyzer {
  const OfferAnalyzer();

  AnalysisResult analyze(
    RideOffer offer,
    CategoryRule rule,
  ) {
    final reasons = <String>[];

    if (rule.minValue != null && offer.value < rule.minValue!) {
      reasons.add('Valor abaixo do minimo');
    }

    if (rule.maxDistanceKm != null &&
        offer.totalDistanceKm > rule.maxDistanceKm!) {
      reasons.add('Distancia total acima do maximo');
    }

    if (rule.maxTimeMin != null &&
        offer.totalTimeMin > rule.maxTimeMin!) {
      reasons.add('Tempo total acima do maximo');
    }

    if (rule.maxPickupDistanceKm != null &&
        offer.pickupDistanceKm > rule.maxPickupDistanceKm!) {
      reasons.add('Distancia ate o embarque acima do maximo');
    }

    if (rule.maxPickupTimeMin != null &&
        offer.pickupTimeMin > rule.maxPickupTimeMin!) {
      reasons.add('Tempo ate o embarque acima do maximo');
    }

    if (rule.minReaisPerKm != null &&
        offer.reaisPerKm < rule.minReaisPerKm!) {
      reasons.add('R\$/km abaixo do minimo');
    }

    if (rule.minReaisPerHour != null &&
        offer.reaisPerHour < rule.minReaisPerHour!) {
      reasons.add('R\$/hora abaixo do minimo');
    }

    return AnalysisResult(
      accepted: reasons.isEmpty,
      reasons: reasons,
    );
  }
}
