import '../core/ride_offer.dart';

/// Leitor de texto das ofertas exibidas pelos aplicativos de motorista.
/// O texto pode chegar fragmentado ou sem rótulos explícitos de origem/destino.
class TextOfferReader {
  const TextOfferReader();

  RideOffer? read(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return null;

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
    final distances = RegExp(r'(\d+(?:[\.,]\d+)?)\s*km')
        .allMatches(normalized)
        .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '.')))
        .whereType<double>()
        .toList();

    final durations = _durations(normalized);
    if (value == null || distances.isEmpty) return null;

    // Uber normalmente apresenta primeiro a distância/tempo até o embarque
    // e depois a distância/tempo da viagem.
    final pickupKm = distances.length > 1 ? distances[0] : 0.0;
    final tripKm = distances.length > 1 ? distances[1] : distances[0];
    final pickupMin = durations.length > 1 ? durations[0] : 0;
    final tripMin = durations.length > 1
        ? durations[1]
        : (durations.isNotEmpty ? durations[0] : 0);

    final addresses = _extractAddresses(normalized);

    return RideOffer(
      platform: platform,
      category: category,
      offerType: offerType,
      paymentType: paymentType,
      value: value,
      origin: addresses.$1,
      destination: addresses.$2,
      pickupDistanceKm: pickupKm,
      tripDistanceKm: tripKm,
      pickupTimeMin: pickupMin,
      tripTimeMin: tripMin,
    );
  }

  String _normalize(String text) => text
      .toLowerCase()
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  PlatformType _platform(String text) {
    if (text.contains('uber')) return PlatformType.uber;
    if (RegExp(r'\b99\b').hasMatch(text)) return PlatformType.nineNine;
    if (text.contains('ifood')) return PlatformType.ifood;
    if (text.contains('rappi')) return PlatformType.rappi;
    if (text.contains('lalamove')) return PlatformType.lalamove;
    return PlatformType.unknown;
  }

  RideCategory _category(String text) {
    if (text.contains('comfort')) return RideCategory.comfort;
    if (text.contains('black')) return RideCategory.black;
    if (text.contains('prioridade')) return RideCategory.priority;
    if (text.contains('99plus') || text.contains('99 plus')) return RideCategory.plus;
    if (text.contains('99pop') || text.contains('pop')) return RideCategory.pop;
    if (text.contains('moto')) return RideCategory.moto;
    if (RegExp(r'uber\s*x').hasMatch(text) || text.contains('uberx')) {
      return RideCategory.uberX;
    }
    if (text.contains('ifood')) return RideCategory.delivery;
    return RideCategory.unknown;
  }

  double? _money(String text) {
    final match = RegExp(r'r\$\s*(\d+(?:\.\d{3})*(?:[\.,]\d{1,2})?)')
        .firstMatch(text);
    if (match == null) return null;
    final raw = match.group(1)!.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw);
  }

  List<int> _durations(String text) {
    // Captura "1 h e 5 min", "1h 5min", "4 min" e "1 hora e 5 minutos".
    final expression = RegExp(
      r'(?:(\d+)\s*h(?:ora)?s?\s*(?:e\s*)?)?(\d+)\s*min(?:uto)?s?',
    );
    return expression.allMatches(text).map((match) {
      final hours = int.tryParse(match.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
      return hours * 60 + minutes;
    }).toList();
  }

  (String, String) _extractAddresses(String text) {
    // Nos cartões do Uber os endereços aparecem depois dos tempos/distâncias,
    // sem as palavras "origem" e "destino". Remove metadados conhecidos e
    // conserva os segmentos de endereço restantes quando disponíveis.
    final cleaned = text
        .replaceAll(RegExp(r'r\$\s*\d+(?:\.\d{3})*(?:[\.,]\d{1,2})?'), ' ')
        .replaceAll(RegExp(r'\d+(?:[\.,]\d+)?\s*km'), ' ')
        .replaceAll(RegExp(r'(?:(\d+)\s*h(?:ora)?s?\s*(?:e\s*)?)?\d+\s*min(?:uto)?s?'), ' ')
        .replaceAll(RegExp(r'\d+(?:[\.,]\d+)?\s*/\s*km\s*aprox\.?'), ' ')
        .replaceAll(RegExp(r'uber\s*x|uberx|exclusivo|viagem longa|mais de 45 min'), ' ')
        .replaceAll(RegExp(r'\d{1,2}[\.,]\d{2}\s*\(\d+\)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final labeledOrigin = _extractAfter(cleaned, 'origem');
    final labeledDestination = _extractAfter(cleaned, 'destino');
    if (labeledOrigin.isNotEmpty || labeledDestination.isNotEmpty) {
      return (labeledOrigin, labeledDestination);
    }
    return ('', '');
  }

  String _extractAfter(String text, String label) {
    final match = RegExp('$label\\s*[:\\-]\\s*(.+)').firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }
}
