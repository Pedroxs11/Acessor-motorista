import '../core/category_rules.dart';
import '../core/offer_analyzer.dart';
import '../core/offer_decision.dart';
import 'platform_adapters.dart';

class OfferPipeline {
  final OfferAnalyzer analyzer;

  const OfferPipeline({this.analyzer = const OfferAnalyzer()});

  OfferDecision? process({
    required String packageName,
    required String capturedText,
  }) {
    final adapter = PlatformAdapterRegistry.byPackage(packageName);
    if (adapter == null) return null;

    final offer = adapter.parse(capturedText);
    if (offer == null) return null;

    final rule = DefaultCategoryRules.forCategory(offer.category);
    final analysis = analyzer.analyze(offer, rule);

    return OfferDecision(offer: offer, analysis: analysis);
  }
}
