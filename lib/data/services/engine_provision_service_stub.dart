class EngineProvisionService {
  const EngineProvisionService();

  Future<EngineResolution> ensureTectonic() async {
    return const EngineResolution.unavailable(
      'Local engine provisioning is not available on this platform yet.',
    );
  }

  Future<EngineResolution> ensureTypst() async {
    return const EngineResolution.unavailable(
      'Local engine provisioning is not available on this platform yet.',
    );
  }
}

class EngineResolution {
  const EngineResolution._({
    required this.available,
    required this.executablePath,
    required this.log,
    required this.wasProvisioned,
  });

  const EngineResolution.available({
    required String executablePath,
    String log = '',
    bool wasProvisioned = false,
  }) : this._(
         available: true,
         executablePath: executablePath,
         log: log,
         wasProvisioned: wasProvisioned,
       );

  const EngineResolution.unavailable(String log)
    : this._(
        available: false,
        executablePath: null,
        log: log,
        wasProvisioned: false,
      );

  final bool available;
  final String? executablePath;
  final String log;
  final bool wasProvisioned;
}
