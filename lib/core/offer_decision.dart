import 'offer_analyzer.dart';
import 'ride_offer.dart';

class OfferDecision {
  final RideOffer offer;
  final AnalysisResult analysis;

  const OfferDecision({
    required this.offer,
    required this.analysis,
  });

  String get label => analysis.accepted ? 'BOA' : 'RUIM';
  String get action => analysis.accepted ? 'ACEITAR' : 'NAO ACEITAR';
}
