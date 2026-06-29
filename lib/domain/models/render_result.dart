enum RenderState { idle, rendering, success, failed }

class RenderResult {
  const RenderResult({
    required this.state,
    this.pdfPath,
    this.engine,
    this.log = '',
    this.content,
  });

  const RenderResult.idle() : this(state: RenderState.idle);

  const RenderResult.rendering() : this(state: RenderState.rendering);

  const RenderResult.renderingWithLog(String log)
    : this(state: RenderState.rendering, log: log);

  factory RenderResult.success({
    String? pdfPath,
    String? engine,
    String log = '',
    String? content,
  }) {
    return RenderResult(
      state: RenderState.success,
      pdfPath: pdfPath,
      engine: engine,
      log: log,
      content: content,
    );
  }

  factory RenderResult.failed(String log) {
    return RenderResult(state: RenderState.failed, log: log);
  }

  final RenderState state;
  final String? pdfPath;
  final String? engine;
  final String log;
  final String? content;

  bool get isRendering => state == RenderState.rendering;
  bool get hasPdf => pdfPath != null && pdfPath!.isNotEmpty;
}
