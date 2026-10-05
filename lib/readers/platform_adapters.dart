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
          packageName: 'com.rappi.storekeeper',
          platform: PlatformType.rappi,
        );
}

class LalamoveAdapter extends GenericPlatformAdapter {
  const LalamoveAdapter()
      : super(
          packageName: 'com.lalamove.global.driver.sea',
          platform: PlatformType.lalamove,
        );
}

class LoggiAdapter extends GenericPlatformAdapter {
  const LoggiAdapter()
      : super(
          packageName: 'com.loggi.driverapp',
          platform: PlatformType.loggi,
        );
}

class BorzoAdapter extends GenericPlatformAdapter {
  const BorzoAdapter()
      : super(
          packageName: 'global.dostavista.courier',
          platform: PlatformType.borzo,
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
    BorzoAdapter(),
  ];

  static GenericPlatformAdapter? byPackage(String packageName) {
    for (final adapter in adapters) {
      if (adapter.packageName == packageName) return adapter;
    }
    return null;
  }
}
