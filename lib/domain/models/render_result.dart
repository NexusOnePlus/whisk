enum RenderState { idle, rendering, success, failed }

class RenderResult {
  const RenderResult({
    required this.state,
    this.pdfPath,
    this.engine,
    this.log = '',
  });

  const RenderResult.idle() : this(state: RenderState.idle);

  const RenderResult.rendering() : this(state: RenderState.rendering);

  const RenderResult.success({
    required String pdfPath,
    required String engine,
    String log = '',
  }) : this(
         state: RenderState.success,
         pdfPath: pdfPath,
         engine: engine,
         log: log,
       );

  const RenderResult.failed(String log)
    : this(state: RenderState.failed, log: log);

  final RenderState state;
  final String? pdfPath;
  final String? engine;
  final String log;

  bool get isRendering => state == RenderState.rendering;
  bool get hasPdf => pdfPath != null && pdfPath!.isNotEmpty;
}
