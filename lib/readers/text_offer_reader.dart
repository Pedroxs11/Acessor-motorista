import '../core/ride_offer.dart';

/// Leitor inicial baseado em texto extraido de uma oferta.
/// A captura/OCR de cada plataforma sera conectada a esta camada depois.
class TextOfferReader {
  const TextOfferReader();

  RideOffer? read(String text) {
    final normalized = text.toLowerCase();

    final platform = _platform(normalized);
    final category = _category(normalized);
    final offerType = normalized.contains('negocia')
        ? OfferType.negotiates
        : OfferType.standard;
    final paymentType = normalized.contains('dinheiro')
        ? PaymentType.cash
        : normalized.contains('pix')
            ? PaymentType.pix
            : PaymentType.app;

    final value = _money(normalized);
    final numbers = RegExp(r'(\d+(?:[\.,]\d+)?)\s*km').allMatches(normalized)
        .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '.')))
        .whereType<double>()
        .toList();

    final times = RegExp(r'(\d+)\s*min').allMatches(normalized)
        .map((m) => int.tryParse(m.group(1)!))
        .whereType<int>()
        .toList();

    if (value == null || numbers.isEmpty) return null;

    final pickupKm = numbers.length > 1 ? numbers.first : 0.0;
    final tripKm = numbers.length > 1 ? numbers[1] : numbers.first;
    final pickupMin = times.length > 1 ? times.first : 0.0;
    final tripMin = times.length > 1 ? times[1] : (times.isNotEmpty ? times.first : 0);

    return RideOffer(
      platform: platform,
      category: category,
      offerType: offerType,
      paymentType: paymentType,
      value: value,
      origin: _extractAfter(normalized, 'origem'),
      destination: _extractAfter(normalized, 'destino'),
      pickupDistanceKm: pickupKm,
      tripDistanceKm: tripKm,
      pickupTimeMin: pickupMin,
      tripTimeMin: tripMin,
    );
  }

  PlatformType _platform(String text) {
    if (text.contains('uber')) return PlatformType.uber;
    if (text.contains('99')) return PlatformType.nineNine;
    if (text.contains('ifood')) return PlatformType.ifood;
    return PlatformType.unknown;
  }

  RideCategory _category(String text) {
    if (text.contains('comfort')) return RideCategory.comfort;
    if (text.contains('black')) return RideCategory.black;
    if (text.contains('prioridade')) return RideCategory.priority;
    if (text.contains('99plus') || text.contains('99 plus')) return RideCategory.plus;
    if (text.contains('99pop') || text.contains('pop')) return RideCategory.pop;
    if (text.contains('moto')) return RideCategory.moto;
    if (text.contains('uberx') || text.contains('uber x')) return RideCategory.uberX;
    if (text.contains('ifood')) return RideCategory.delivery;
    return RideCategory.unknown;
  }

  double? _money(String text) {
    final match = RegExp(r'r\$\s*(\d+(?:[\.,]\d+)?)').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  String _extractAfter(String text, String label) {
    final match = RegExp('$label\\s*[:\\-]\\s*(.+)').firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }
}
