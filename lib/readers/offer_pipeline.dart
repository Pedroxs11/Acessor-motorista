import '../core/category_rules.dart';
import '../core/offer_analyzer.dart';
import '../core/offer_decision.dart';
import 'text_offer_reader.dart';

/// Pipeline comum: texto capturado -> oferta normalizada -> analise.
/// A captura real de Android/iOS sera conectada acima desta camada.
class OfferPipeline {
  final TextOfferReader reader;
  final OfferAnalyzer analyzer;

  const OfferPipeline({
    this.reader = const TextOfferReader(),
    this.analyzer = const OfferAnalyzer(),
  });

  OfferDecision? process(String capturedText) {
    final offer = reader.read(capturedText);
    if (offer == null) return null;

    final rule = DefaultCategoryRules.forCategory(offer.category);
    final analysis = analyzer.analyze(offer, rule);

    return OfferDecision(offer: offer, analysis: analysis);
  }
}
