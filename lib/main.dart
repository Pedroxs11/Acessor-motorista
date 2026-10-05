import 'package:flutter/material.dart';

import 'core/offer_decision.dart';
import 'readers/offer_pipeline.dart';

void main() => runApp(const AcessorApp());

class AcessorApp extends StatelessWidget {
  const AcessorApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Acessor Motorista',
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pipeline = const OfferPipeline();
  OfferDecision? _decision;

  void _testOffer() {
    const text = 'UberX R\$ 60,00 Origem: Avenida Paulista Destino: Guarulhos 3 km 9 min 21 km 54 min';
    setState(() => _decision = _pipeline.process(packageName: 'com.ubercab.driver', capturedText: text));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acessor Motorista')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Analise suas ofertas antes de decidir.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('O Acessor calcula R\$/km e R\$/hora e mostra uma recomendação.'),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: _testOffer, icon: const Icon(Icons.play_arrow), label: const Text('Testar análise')),
        const SizedBox(height: 20),
        if (_decision != null) _DecisionCard(decision: _decision!),
      ]),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  final OfferDecision decision;
  const _DecisionCard({required this.decision});
  @override Widget build(BuildContext context) {
    final offer = decision.offer;
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(decision.analysis.accepted ? '🟢 BOA — ACEITAR' : '🔴 RUIM — NÃO ACEITAR', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Text('Plataforma: ${offer.platform.name}'),
      Text('Categoria: ${offer.category.name}'),
      Text('Valor: R\$ ${offer.value.toStringAsFixed(2)}'),
      Text('Distância: ${offer.totalDistanceKm.toStringAsFixed(1)} km'),
      Text('Tempo: ${offer.totalTimeMin} min'),
      Text('R\$/km: ${offer.reaisPerKm.toStringAsFixed(2)}'),
      Text('R\$/hora: ${offer.reaisPerHour.toStringAsFixed(2)}'),
      if (offer.origin.isNotEmpty) Text('Origem: ${offer.origin}'),
      if (offer.destination.isNotEmpty) Text('Destino: ${offer.destination}'),
    ])));
  }
}