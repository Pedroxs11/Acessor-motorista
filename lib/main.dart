import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/offer_decision.dart';
import 'readers/offer_pipeline.dart';

void main() => runApp(const AcessorApp());

class AcessorApp extends StatelessWidget {
  const AcessorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Acessor Motorista',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _overlayChannel = MethodChannel('com.acessor.motorista/floating_overlay');
  bool _overlayEnabled = false;
  static const _captureChannel =
      EventChannel('com.acessor.motorista/offer_capture');
  static const _supportedPackages = <String>{
    'com.ubercab.driver',
    'com.app99.driver',
    'br.com.ifood.driver.app',
    'com.rappi.storekeeper',
    'com.lalamove.global.driver.sea',
    'com.loggi.driverapp',
    'global.dostavista.courier',
  };

  final _pipeline = const OfferPipeline();
  OfferDecision? _decision;
  String _status = 'Aguardando evento de acessibilidade...';
  String _lastPackage = '';
  String _lastCapturedText = '';
  String _lastCaptureSource = '';
  int _lastEventType = -1;
  String _diagnosis = 'Abra o Uber ou 99 e aguarde uma oferta aparecer.';

  @override
  void initState() {
    super.initState();
    _captureChannel.receiveBroadcastStream().listen(
      _onCapture,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _status = 'Erro no canal de captura.';
          _diagnosis = error.toString();
        });
      },
    );
  }

  void _onCapture(dynamic event) {
    if (event is! Map) return;
    final packageName = event['packageName']?.toString() ?? '';
    final text = event['text']?.toString() ?? '';
    final captureSource = event['captureSource']?.toString() ?? 'unknown';
    final eventType = int.tryParse(event['eventType']?.toString() ?? '') ?? -1;
    if (packageName.isEmpty) return;

    final decision = _pipeline.process(
      packageName: packageName,
      capturedText: text,
    );

    if (!mounted) return;
    setState(() {
      _lastPackage = packageName;
      _lastCapturedText = text;
      _lastCaptureSource = captureSource;
      _lastEventType = eventType;

      // Ignore empty/unparsed follow-up events for the visible result.
      // Driver apps emit many window-change events after the offer appears;
      // those events must not erase the last successfully analyzed offer.
      if (decision != null) {
        _decision = decision;
        _status = 'Oferta analisada automaticamente. Última análise mantida na tela.';
      } else if (_decision == null) {
        _status = 'Evento recebido, mas a oferta não foi interpretada.';
      } else {
        _status = 'Última oferta analisada mantida. Aguardando nova oferta válida.';
      }
      _diagnosis = _diagnose(packageName, text, decision);
    });
  }

  Future<void> _refreshOverlayPermission() async {
    try {
      final allowed = await _overlayChannel.invokeMethod<bool>('hasPermission') ?? false;
      if (mounted) setState(() => _overlayEnabled = allowed);
    } catch (_) {}
  }

  Future<void> _requestOverlayPermission() async {
    await _overlayChannel.invokeMethod('requestPermission');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _refreshOverlayPermission();
    if (_overlayEnabled && _decision != null) await _showFloatingDecision(_decision!);
  }

  Future<void> _showFloatingDecision(OfferDecision decision) async {
    final offer = decision.offer;
    try {
      await _overlayChannel.invokeMethod('show', {
        'label': decision.analysis.accepted ? 'BOA • ACEITAR' : 'RUIM • NÃO ACEITAR',
        'accepted': decision.analysis.accepted,
        'value': 'R\\$ ${offer.value.toStringAsFixed(2)}',
        'perKm': 'R\\$ ${offer.reaisPerKm.toStringAsFixed(2)}',
        'perHour': 'R\\$ ${offer.reaisPerHour.toStringAsFixed(0)}',
        'perMinute': offer.totalTimeMin > 0 ? 'R\\$ ${(offer.value / offer.totalTimeMin).toStringAsFixed(2)}' : '',
        'distance': '${offer.totalDistanceKm.toStringAsFixed(1)} km',
        'time': '${offer.totalTimeMin} min',
        'category': offer.category.name,
        'origin': offer.origin,
        'destination': offer.destination,
      });
    } catch (_) {}
  }

  Future<void> _hideFloatingDecision() async {
    try { await _overlayChannel.invokeMethod('hide'); } catch (_) {}
  }

  String _diagnose(String packageName, String text, OfferDecision? decision) {
    if (!_supportedPackages.contains(packageName)) {
      return 'O pacote recebido não está cadastrado nos leitores.';
    }
    if (text.trim().isEmpty) {
      return 'O evento chegou sem texto acessível.';
    }
    if (decision != null) {
      return 'Captura e interpretação concluídas.';
    }
    final normalized = text.toLowerCase().replaceAll('\u00a0', ' ');
    final hasMoney = RegExp(r'r\$\s*\d').hasMatch(normalized);
    final hasDistance = RegExp(
      r'\d+(?:[\.,]\d+)?\s*km(?=\s|\)|,|\.|$)',
    ).hasMatch(normalized);

    if (!hasMoney && !hasDistance) {
      return 'Texto recebido, mas não encontrei valor no formato R\$ nem distância em km. Confira o texto abaixo.';
    }
    if (!hasMoney) {
      return 'Encontrei distância, mas não encontrei valor no formato R\$.';
    }
    if (!hasDistance) {
      return 'Encontrei valor, mas não encontrei distância em km. O leitor atual exige os dois.';
    }
    return 'O texto contém valor e distância, mas o leitor rejeitou a oferta. Precisamos ajustar as regras de interpretação.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Acessor Motorista')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Análise automática de ofertas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_status),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: _overlayEnabled ? (_decision == null ? null : () => _showFloatingDecision(_decision!)) : _requestOverlayPermission,
                icon: Icon(_overlayEnabled ? Icons.layers : Icons.layers_outlined),
                label: Text(_overlayEnabled ? 'Mostrar cartão flutuante' : 'Ativar cartão flutuante'),
              ),
              if (_overlayEnabled) OutlinedButton(onPressed: _hideFloatingDecision, child: const Text('Ocultar cartão')),
            ]),
            Text(_overlayEnabled ? 'Sobreposição autorizada' : 'É necessária permissão para exibir sobre outros apps.'),
            const SizedBox(height: 8),
            Text('Diagnóstico: $_diagnosis'),
            const SizedBox(height: 20),
            if (_decision != null) _DecisionCard(decision: _decision!),
            const SizedBox(height: 20),
            ExpansionTile(
              title: const Text('Diagnóstico da captura'),
              subtitle: const Text('Informações locais para descobrir onde a leitura falha'),
              childrenPadding: const EdgeInsets.all(12),
              children: [
                SelectableText(
                  'Pacote recebido: ${_lastPackage.isEmpty ? 'nenhum' : _lastPackage}',
                ),
                const SizedBox(height: 8),
                SelectableText('Tipo de evento Android: ${_lastEventType < 0 ? 'desconhecido' : _lastEventType}'),
                const SizedBox(height: 8),
                SelectableText('Fonte do texto: ${_lastCaptureSource.isEmpty ? 'nenhuma' : _lastCaptureSource}'),
                const SizedBox(height: 8),
                SelectableText(
                  'Caracteres capturados: ${_lastCapturedText.length}',
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    _lastCapturedText.isEmpty
                        ? 'Nenhum texto capturado ainda.'
                        : _lastCapturedText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'O Acessor analisa a oferta. A decisão final e qualquer aceite continuam sob controle do motorista.',
            ),
          ],
        ),
      );
}

class _DecisionCard extends StatelessWidget {
  final OfferDecision decision;

  const _DecisionCard({required this.decision});

  @override
  Widget build(BuildContext context) {
    final offer = decision.offer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              decision.analysis.accepted
                  ? '🟢 BOA — ACEITAR'
                  : '🔴 RUIM — NÃO ACEITAR',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Plataforma: ${offer.platform.name}'),
            Text('Categoria: ${offer.category.name}'),
            Text('Valor: R\$ ${offer.value.toStringAsFixed(2)}'),
            Text('Distância: ${offer.totalDistanceKm.toStringAsFixed(1)} km'),
            Text('Tempo: ${offer.totalTimeMin} min'),
            Text('R\$/km: ${offer.reaisPerKm.toStringAsFixed(2)}'),
            Text('R\$/hora: ${offer.reaisPerHour.toStringAsFixed(2)}'),
            if (offer.origin.isNotEmpty) Text('Origem: ${offer.origin}'),
            if (offer.destination.isNotEmpty)
              Text('Destino: ${offer.destination}'),
          ],
        ),
      ),
    );
  }
}
