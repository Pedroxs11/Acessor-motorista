import '../core/ride_offer.dart';
import 'platform_adapter.dart';

class UberAdapter extends GenericPlatformAdapter {
  const UberAdapter()
      : super(
          packageName: 'com.ubercab.driver',
          platform: PlatformType.uber,
        );
}

class NineNineAdapter extends GenericPlatformAdapter {
  const NineNineAdapter()
      : super(
          packageName: 'com.app99.driver',
          platform: PlatformType.nineNine,
        );
}

class IFoodAdapter extends GenericPlatformAdapter {
  const IFoodAdapter()
      : super(
          packageName: 'br.com.ifood.driver.app',
          platform: PlatformType.ifood,
        );
}

class RappiAdapter extends GenericPlatformAdapter {
  const RappiAdapter()
      : super(
          packageName: 'com.grability.rappi',
          platform: PlatformType.ifood,
        );
}

class LalamoveAdapter extends GenericPlatformAdapter {
  const LalamoveAdapter()
      : super(
          packageName: 'com.lalamove.global.driver',
          platform: PlatformType.ifood,
        );
}

class LoggiAdapter extends GenericPlatformAdapter {
  const LoggiAdapter()
      : super(
          packageName: 'com.loggi.driver',
          platform: PlatformType.ifood,
        );
}

class PlatformAdapterRegistry {
  static const adapters = <GenericPlatformAdapter>[
    UberAdapter(),
    NineNineAdapter(),
    IFoodAdapter(),
    RappiAdapter(),
    LalamoveAdapter(),
    LoggiAdapter(),
  ];

  static GenericPlatformAdapter? byPackage(String packageName) {
    for (final adapter in adapters) {
      if (adapter.packageName == packageName) return adapter;
    }
    return null;
  }
}
