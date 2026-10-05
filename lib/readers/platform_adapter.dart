import '../core/ride_offer.dart';
import 'text_offer_reader.dart';

abstract class PlatformAdapter {
  String get packageName;
  PlatformType get platform;

  RideOffer? parse(String capturedText);
}

class GenericPlatformAdapter implements PlatformAdapter {
  final TextOfferReader reader;
  @override final String packageName;
  @override final PlatformType platform;

  const GenericPlatformAdapter({
    required this.packageName,
    required this.platform,
    this.reader = const TextOfferReader(),
  });

  @override
  RideOffer? parse(String capturedText) => reader.read(capturedText);
}
