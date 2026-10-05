import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/offer_decision.dart';
import 'readers/offer_pipeline.dart';

void main() => runApp(const AcessorApp());

class AcessorApp extends StatelessWidget {
  const AcessorApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'Acessor Motorista',
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _captureChannel = EventChannel('com.acessor.motorista/offer_capture');
  final _pipeline = const OfferPipeline();
  OfferDecision? _decision;
  String _status = 'Aguardando oferta...';

  @override void initState() { super.initState(); _captureChannel.receiveBroadcastStream().listen(_onCapture); }

  void _onCapture(dynamic event) {
    if (event is! Map) return;
    final packageName = event['packageName']?.toString();
    final text = event['text']?.toString();
    if (packageName == null || text == null) return;
    final decision = _pipeline.process(packageName: packageName, capturedText: text);
    if (!mounted) return;
    setState(() {
      _decision = decision;
      _status = decision != null ? 'Oferta analisada automaticamente.' : 'Oferta detectada, mas ainda não reconhecida.';
    });
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Acessor Motorista')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Análise automática de ofertas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Text(_status), const SizedBox(height: 20),
      if (_decision != null) _DecisionCard(decision: _decision!),
      const SizedBox(height: 20),
      const Text('O Acessor analisa a oferta. A decisão final e qualquer aceite continuam sob controle do motorista.'),
    ]),
  );
}

class _DecisionCard extends StatelessWidget {
  final OfferDecision decision;
  const _DecisionCard({required this.decision});
  @override Widget build(BuildContext context) {
    final offer = decision.offer;
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(decision.analysis.accepted ? '🟢 BOA — ACEITAR' : '🔴 RUIM — NÃO ACEITAR', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Text('Plataforma: \${offer.platform.name}'),
      Text('Categoria: \${offer.category.name}'),
      Text('Valor: R\$ \${offer.value.toStringAsFixed(2)}'),
      Text('Distância: \${offer.totalDistanceKm.toStringAsFixed(1)} km'),
      Text('Tempo: \${offer.totalTimeMin} min'),
      Text('R\$/km: \${offer.reaisPerKm.toStringAsFixed(2)}'),
      Text('R\$/hora: \${offer.reaisPerHour.toStringAsFixed(2)}'),
      if (offer.origin.isNotEmpty) Text('Origem: \${offer.origin}'),
      if (offer.destination.isNotEmpty) Text('Destino: \${offer.destination}'),
    ])));
  }
}