import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/driver_criteria.dart';
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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _overlayChannel = MethodChannel('com.acessor.motorista/floating_overlay');
  bool _overlayEnabled = false;
  bool _accessibilityEnabled = false;
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
  final _minValueController = TextEditingController(text: '0');
  final _minPerKmController = TextEditingController(text: '2');
  final _minPerHourController = TextEditingController(text: '40');
  final _maxPickupDistanceController = TextEditingController(text: '0');
  final _maxPickupTimeController = TextEditingController(text: '0');
  DriverCriteria? _criteria;
  bool _savingCriteria = false;
  OfferDecision? _decision;
  String _status = 'Aguardando evento de acessibilidade...';
  String _lastPackage = '';
  String _lastCapturedText = '';
  String _lastCaptureSource = '';
  int _lastEventType = -1;
  String _diagnosis = 'Abra o Uber ou 99 e aguarde uma oferta aparecer.';
  Timer? _overlayHideTimer;
  String _lastOfferFingerprint = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
    _loadCriteria();
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
      criteria: _criteria,
    );

    // Automatically keep the floating card synchronized with each valid offer.
    // Debounce blank/unparsed accessibility events so transient events don't hide it.
    if (decision != null) {
      _overlayHideTimer?.cancel();
      final offer = decision.offer;
      final fingerprint = [
        packageName,
        offer.value.toStringAsFixed(2),
        offer.totalDistanceKm.toStringAsFixed(2),
        offer.totalTimeMin.toString(),
        offer.category.name,
        offer.origin,
        offer.destination,
      ].join('|');
      if (_overlayEnabled && fingerprint != _lastOfferFingerprint) {
        _lastOfferFingerprint = fingerprint;
        _showFloatingDecision(decision);
      }
    } else if (_overlayEnabled && _decision != null) {
      _overlayHideTimer?.cancel();
      _overlayHideTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) _hideFloatingDecision();
      });
    }

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  @override
  void dispose() {
    _overlayHideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _minValueController.dispose();
    _minPerKmController.dispose();
    _minPerHourController.dispose();
    _maxPickupDistanceController.dispose();
    _maxPickupTimeController.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissions() async {
    var overlay = false;
    var accessibility = false;
    try {
      overlay = await _overlayChannel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {}
    try {
      accessibility = await _overlayChannel.invokeMethod<bool>('hasAccessibilityPermission') ?? false;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _overlayEnabled = overlay;
      _accessibilityEnabled = accessibility;
    });
  }

  Future<void> _loadCriteria() async {
    try {
      final data = await _overlayChannel.invokeMapMethod<String, dynamic>('loadCriteria');
      if (data == null || !mounted) return;
      final criteria = DriverCriteria.fromMap(data);
      setState(() {
        _minValueController.text = criteria.minValue.toStringAsFixed(2);
        _minPerKmController.text = criteria.minReaisPerKm.toStringAsFixed(2);
        _minPerHourController.text = criteria.minReaisPerHour.toStringAsFixed(2);
        _maxPickupDistanceController.text = criteria.maxPickupDistanceKm.toStringAsFixed(1);
        _maxPickupTimeController.text = criteria.maxPickupTimeMin.toString();
        _criteria = data['enabled'] == true ? criteria : null;
      });
    } catch (_) {
      // Settings remain editable with suggested initial values if loading fails.
    }
  }

  double _readNumber(TextEditingController controller) {
    return double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
  }

  Future<void> _saveCriteria() async {
    final values = [
      _readNumber(_minValueController),
      _readNumber(_minPerKmController),
      _readNumber(_minPerHourController),
      _readNumber(_maxPickupDistanceController),
      _readNumber(_maxPickupTimeController),
    ];
    if (values.any((value) => !value.isFinite || value < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use somente valores iguais ou maiores que zero.')),
      );
      return;
    }
    final criteria = DriverCriteria(
      minValue: values[0],
      minReaisPerKm: values[1],
      minReaisPerHour: values[2],
      maxPickupDistanceKm: values[3],
      maxPickupTimeMin: values[4].toInt(),
    );
    setState(() => _savingCriteria = true);
    try {
      final saved = await _overlayChannel.invokeMethod<bool>(
        'saveCriteria',
        criteria.toMap(),
      );
      if (saved != true) throw PlatformException(code: 'SAVE_FAILED');
      if (!mounted) return;
      final revisedDecision = _lastPackage.isNotEmpty
          ? _pipeline.process(
              packageName: _lastPackage,
              capturedText: _lastCapturedText,
              criteria: criteria,
            )
          : null;
      setState(() {
        _criteria = criteria;
        if (revisedDecision != null) _decision = revisedDecision;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Critérios salvos neste aparelho.')),
      );
      if (_overlayEnabled && _decision != null) {
        await _showFloatingDecision(_decision!);
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar os critérios.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCriteria = false);
    }
  }

  Widget _criteriaField(String label, TextEditingController controller) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _requestAccessibilityPermission() async {
    await _overlayChannel.invokeMethod('requestAccessibilityPermission');
  }

  Future<void> _requestOverlayPermission() async {
    await _overlayChannel.invokeMethod('requestPermission');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _refreshPermissions();
    if (_overlayEnabled && _decision != null) await _showFloatingDecision(_decision!);
  }

  Future<void> _showFloatingDecision(OfferDecision decision) async {
    final offer = decision.offer;
    try {
      await _overlayChannel.invokeMethod('show', {
        'label': decision.analysis.accepted ? 'BOA • ACEITAR' : 'RUIM • NÃO ACEITAR',
        'accepted': decision.analysis.accepted,
        'value': 'R\$ ${offer.value.toStringAsFixed(2)}',
        'perKm': 'R\$ ${offer.reaisPerKm.toStringAsFixed(2)}',
        'perHour': 'R\$ ${offer.reaisPerHour.toStringAsFixed(0)}',
        'perMinute': offer.totalTimeMin > 0 ? 'R\$ ${(offer.value / offer.totalTimeMin).toStringAsFixed(2)}' : '',
        'distance': '${offer.totalDistanceKm.toStringAsFixed(1)} km',
        'time': '${offer.totalTimeMin} min',
        'category': offer.category.name,
        'origin': offer.origin,
        'destination': offer.destination,
      });
    } catch (_) {}
  }

  Future<void> _hideFloatingDecision() async {
    _lastOfferFingerprint = '';
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuração inicial',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Para analisar as ofertas do Uber e 99 por cima de outros apps, ative as duas permissões abaixo. O Android vai pedir sua confirmação.',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _accessibilityEnabled ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: _accessibilityEnabled ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Acessibilidade: ${_accessibilityEnabled ? 'ativa' : 'precisa ativar'}')),
                        TextButton(
                          onPressed: _requestAccessibilityPermission,
                          child: Text(_accessibilityEnabled ? 'Revisar' : 'Ativar'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          _overlayEnabled ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: _overlayEnabled ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Cartão flutuante: ${_overlayEnabled ? 'permitido' : 'precisa permitir'}')),
                        TextButton(
                          onPressed: _requestOverlayPermission,
                          child: Text(_overlayEnabled ? 'Revisar' : 'Ativar'),
                        ),
                      ],
                    ),
                    if (_accessibilityEnabled && _overlayEnabled) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Permissões concluídas. Abra o Uber ou 99 e aguarde uma oferta para testar o cartão.',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Critérios da corrida',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _criteria == null
                          ? 'Você está usando as regras atuais por categoria. Salve para ativar seus próprios limites.'
                          : 'Critérios personalizados ativos neste aparelho.',
                      style: TextStyle(
                        color: _criteria == null ? Colors.grey[700] : Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _criteriaField('Valor mínimo (R\$)', _minValueController),
                        const SizedBox(width: 10),
                        _criteriaField('Mínimo R\$/km', _minPerKmController),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _criteriaField('Mínimo R\$/hora', _minPerHourController),
                        const SizedBox(width: 10),
                        _criteriaField('Máx. embarque (km)', _maxPickupDistanceController),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _criteriaField('Máx. espera (min)', _maxPickupTimeController),
                        const SizedBox(width: 10),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Preencha 0 para desativar um limite. Valor mínimo, R\$/km e R\$/hora se aplicam às ofertas; distância e tempo até o embarque usam os dados disponíveis na tela da plataforma. Os limites totais atuais continuam variando conforme a categoria.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _savingCriteria ? null : _saveCriteria,
                        icon: _savingCriteria
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_savingCriteria ? 'Salvando...' : 'Salvar critérios'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
