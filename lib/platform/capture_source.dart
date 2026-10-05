/// Contrato comum para captura de ofertas.
/// Cada plataforma terá seu próprio adaptador de captura.
abstract class CaptureSource {
  Future<void> start();
  Future<void> stop();

  Stream<String> get capturedText;
}
