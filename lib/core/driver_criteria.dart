import 'offer_analyzer.dart';

/// Preferências de aceite definidas pelo motorista.
/// Valor zero desativa aquele limite mínimo/máximo.
class DriverCriteria {
  final double minValue;
  final double minReaisPerKm;
  final double minReaisPerHour;
  final double maxPickupDistanceKm;
  final int maxPickupTimeMin;

  const DriverCriteria({
    this.minValue = 0,
    this.minReaisPerKm = 2,
    this.minReaisPerHour = 40,
    this.maxPickupDistanceKm = 0,
    this.maxPickupTimeMin = 0,
  });

  factory DriverCriteria.fromMap(Map<dynamic, dynamic> data) {
    double readDouble(String key, double fallback) {
      final value = data[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    int readInt(String key, int fallback) {
      final value = data[key];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return DriverCriteria(
      minValue: readDouble('minValue', 0),
      minReaisPerKm: readDouble('minReaisPerKm', 2),
      minReaisPerHour: readDouble('minReaisPerHour', 40),
      maxPickupDistanceKm: readDouble('maxPickupDistanceKm', 0),
      maxPickupTimeMin: readInt('maxPickupTimeMin', 0),
    );
  }

  Map<String, Object> toMap() => {
        'minValue': minValue,
        'minReaisPerKm': minReaisPerKm,
        'minReaisPerHour': minReaisPerHour,
        'maxPickupDistanceKm': maxPickupDistanceKm,
        'maxPickupTimeMin': maxPickupTimeMin,
      };

  CategoryRule applyTo(CategoryRule defaults) => CategoryRule(
        minValue: minValue > 0 ? minValue : null,
        maxDistanceKm: defaults.maxDistanceKm,
        maxTimeMin: defaults.maxTimeMin,
        minReaisPerKm: minReaisPerKm > 0 ? minReaisPerKm : null,
        minReaisPerHour: minReaisPerHour > 0 ? minReaisPerHour : null,
        maxPickupDistanceKm:
            maxPickupDistanceKm > 0 ? maxPickupDistanceKm : null,
        maxPickupTimeMin: maxPickupTimeMin > 0 ? maxPickupTimeMin : null,
      );
}
