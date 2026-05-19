import 'dart:io';

import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/domain/models/whisk_file.dart';

class DocumentRenderService {
  const DocumentRenderService();

  Future<RenderResult> render({
    required String environmentId,
    required WhiskFile file,
  }) async {
    if (environmentId != 'latex') {
      return RenderResult.failed(
        'Renderer for .$environmentId is not wired yet. Phase order is LaTeX, Typst, Markdown, then Mermaid.',
      );
    }

    return _renderLatex(file);
  }

  Future<RenderResult> _renderLatex(WhiskFile file) async {
    final root = await Directory.systemTemp.createTemp('whisk-latex-');
    final build = Directory('${root.path}${Platform.pathSeparator}build');
    await build.create(recursive: true);

    final source = File('${root.path}${Platform.pathSeparator}main.tex');
    await source.writeAsString(file.content);

    final attempts = <_RenderAttempt>[
      _RenderAttempt(
        engine: 'tectonic',
        executable: 'tectonic',
        arguments: ['main.tex', '--outdir', 'build'],
      ),
      _RenderAttempt(
        engine: 'latexmk',
        executable: 'latexmk',
        arguments: [
          '-pdf',
          '-interaction=nonstopmode',
          '-halt-on-error',
          '-outdir=build',
          'main.tex',
        ],
      ),
      _RenderAttempt(
        engine: 'pdflatex',
        executable: 'pdflatex',
        arguments: [
          '-interaction=nonstopmode',
          '-halt-on-error',
          '-output-directory=build',
          'main.tex',
        ],
      ),
    ];

    final logs = StringBuffer();
    for (final attempt in attempts) {
      final result = await _tryRun(attempt, root.path);
      logs
        ..writeln('> ${attempt.executable} ${attempt.arguments.join(' ')}')
        ..writeln(result.log.trim())
        ..writeln();

      if (!result.success) continue;

      final pdf = File('${build.path}${Platform.pathSeparator}main.pdf');
      if (await pdf.exists()) {
        return RenderResult.success(
          pdfPath: pdf.path,
          engine: attempt.engine,
          log: logs.toString(),
        );
      }
    }

    return RenderResult.failed(
      'Could not render LaTeX. Install one of: tectonic, latexmk, or pdflatex.\n\n${logs.toString()}',
    );
  }

  Future<_ProcessResult> _tryRun(
    _RenderAttempt attempt,
    String workingDirectory,
  ) async {
    try {
      final result = await Process.run(
        attempt.executable,
        attempt.arguments,
        workingDirectory: workingDirectory,
        runInShell: Platform.isWindows,
      );
      return _ProcessResult(
        success: result.exitCode == 0,
        log: '${result.stdout}\n${result.stderr}',
      );
    } on ProcessException catch (error) {
      return _ProcessResult(success: false, log: error.message);
    }
  }
}

class _RenderAttempt {
  const _RenderAttempt({
    required this.engine,
    required this.executable,
    required this.arguments,
  });

  final String engine;
  final String executable;
  final List<String> arguments;
}

class _ProcessResult {
  const _ProcessResult({required this.success, required this.log});

  final bool success;
  final String log;
}
