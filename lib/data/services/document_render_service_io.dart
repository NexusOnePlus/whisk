import 'dart:developer' as dev;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:whisk/data/services/engine_provision_service.dart';
import 'package:whisk/data/services/workspace_config_service.dart';
import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/domain/models/whisk_file.dart';

class DocumentRenderService {
  const DocumentRenderService({
    this.engineProvisionService = const EngineProvisionService(),
  });

  final EngineProvisionService engineProvisionService;

  static Future<void> _safeWriteFile(File target, String content) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await target.writeAsString(content);
        return;
      } on FileSystemException {
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
        }
      }
    }
  }

  Future<RenderResult> render({
    required String environmentId,
    required WhiskFile file,
  }) async {
    return switch (environmentId) {
      'latex' => _renderLatex(file),
      'typst' => _renderTypst(file),
      _ => RenderResult.failed(
        'Renderer for $environmentId is not wired yet. Phase order is LaTeX, Typst, Markdown, then Mermaid.',
      ),
    };
  }

  Future<RenderResult> _renderLatex(WhiskFile file) async {
    final workspace = await _prepareWorkspace(file);
    final root = workspace.projectRoot;
    final build = workspace.buildRoot;

    final source = File(workspace.sourcePath);
    await _safeWriteFile(source, file.content);

    final tectonic = await engineProvisionService.ensureTectonic();
    final preferredEngine = workspace.config.latexEngine;
    final attempts = <_RenderAttempt>[];

    if (preferredEngine == 'auto' || preferredEngine == 'tectonic') {
      if (tectonic.available && tectonic.executablePath != null) {
        attempts.add(
          _RenderAttempt(
            engine: 'tectonic',
            executable: tectonic.executablePath!,
            arguments: [
              workspace.entrypoint,
              '--outdir',
              workspace.buildArgument,
            ],
          ),
        );
      }
    }

    if (preferredEngine == 'auto' || preferredEngine == 'latexmk') {
      attempts.add(
        _RenderAttempt(
          engine: 'latexmk',
          executable: 'latexmk',
          arguments: [
            '-pdf',
            '-interaction=nonstopmode',
            '-halt-on-error',
            '-outdir=${workspace.buildArgument}',
            workspace.entrypoint,
          ],
        ),
      );
    }

    if (preferredEngine == 'auto' || preferredEngine == 'pdflatex') {
      attempts.add(
        _RenderAttempt(
          engine: 'pdflatex',
          executable: 'pdflatex',
          arguments: [
            '-interaction=nonstopmode',
            '-halt-on-error',
            '-output-directory=${workspace.buildArgument}',
            workspace.entrypoint,
          ],
        ),
      );
    }

    final logs = StringBuffer();
    logs
      ..writeln('project: ${root.path}')
      ..writeln('build: ${build.path}')
      ..writeln('cache: ${workspace.cacheRoot.path}')
      ..writeln(tectonic.log.trim())
      ..writeln();

    for (final attempt in attempts) {
      final result = await _tryRun(attempt, root.path, workspace.environment);
      logs
        ..writeln('> ${attempt.executable} ${attempt.arguments.join(' ')}')
        ..writeln(result.log.trim())
        ..writeln();

      if (!result.success) continue;

      final baseName = source.uri.pathSegments.last.replaceAll(
        RegExp(r'\.tex$', caseSensitive: false),
        '',
      );
      // LaTeX always outputs to baseName.pdf by default based on the entrypoint
      final defaultPdf = File(
        '${build.path}${Platform.pathSeparator}$baseName.pdf',
      );

      if (await defaultPdf.exists()) {
        final uniqueId = DateTime.now().millisecondsSinceEpoch;
        final finalPdf = File(
          '${build.path}${Platform.pathSeparator}${baseName}_$uniqueId.pdf',
        );

        // Cleanup old pdfs
        try {
          final dir = Directory(build.path);
          if (dir.existsSync()) {
            for (final entity in dir.listSync()) {
              if (entity is File &&
                  entity.path.endsWith('.pdf') &&
                  entity.path != defaultPdf.path) {
                try {
                  entity.deleteSync();
                } catch (e) {
                  dev.log('Failed to delete old PDF: $e', name: 'DocumentRenderService');
                }
              }
            }
          }
        } catch (e) {
          dev.log('Failed to list build directory: $e', name: 'DocumentRenderService');
        }

      try {
        await defaultPdf.rename(finalPdf.path);
        await _generateThumbnail(finalPdf.path, build.path);
        return RenderResult.success(
          pdfPath: finalPdf.path,
          engine: attempt.engine,
          log: logs.toString(),
        );
      } catch (_) {
        await _generateThumbnail(defaultPdf.path, build.path);
        return RenderResult.success(
          pdfPath: defaultPdf.path,
          engine: attempt.engine,
          log: logs.toString(),
        );
      }
      }
    }

    return RenderResult.failed(
      'Could not render LaTeX. Whisk tried bundled/downloaded Tectonic first, then latexmk and pdflatex.\n\n${logs.toString()}',
    );
  }

  Future<RenderResult> _renderTypst(WhiskFile file) async {
    final workspace = await _prepareWorkspace(file, engine: 'typst');
    final root = workspace.projectRoot;
    final build = workspace.buildRoot;

    final source = File(workspace.sourcePath);
    await _safeWriteFile(source, file.content);

    final preferredEngine = workspace.config.typstEngine;
    if (preferredEngine != 'auto' && preferredEngine != 'typst') {
      return RenderResult.failed(
        'Typst engine "$preferredEngine" is not supported. Use "auto" or "typst".',
      );
    }

    final typst = await engineProvisionService.ensureTypst();
    final logs = StringBuffer();
    logs
      ..writeln('project: ${root.path}')
      ..writeln('build: ${build.path}')
      ..writeln('cache: ${workspace.cacheRoot.path}')
      ..writeln(typst.log.trim())
      ..writeln();

    if (typst.available && typst.executablePath != null) {
      final baseName = Uri.file(workspace.sourcePath).pathSegments.last
          .replaceAll(RegExp(r'\.typ$', caseSensitive: false), '');
      final uniqueId = DateTime.now().millisecondsSinceEpoch;
      final pdfName = '${baseName}_$uniqueId.pdf';
      final pdfPath = '${build.path}${Platform.pathSeparator}$pdfName';

      // Cleanup old pdfs
      try {
        final dir = Directory(build.path);
        if (dir.existsSync()) {
          for (final entity in dir.listSync()) {
            if (entity is File && entity.path.endsWith('.pdf')) {
              try {
                entity.deleteSync();
              } catch (e) {
                dev.log('Failed to delete old typst PDF: $e', name: 'DocumentRenderService');
              }
            }
          }
        }
      } catch (e) {
        dev.log('Failed to list typst build directory: $e', name: 'DocumentRenderService');
      }

      final result = await _tryRun(
        _RenderAttempt(
          engine: 'typst',
          executable: typst.executablePath!,
          arguments: [
            'compile',
            workspace.entrypoint,
            pdfPath,
            '--root',
            root.path,
          ],
        ),
        root.path,
        workspace.environment,
      );
      logs
        ..writeln('> typst compile ${workspace.entrypoint}')
        ..writeln(result.log.trim())
        ..writeln();

      if (result.success) {
        final pdf = File(pdfPath);
        if (await pdf.exists()) {
          await _generateThumbnail(pdf.path, build.path);
          return RenderResult.success(
            pdfPath: pdf.path,
            engine: 'typst',
            log: logs.toString(),
          );
        }
      }
    }

    return RenderResult.failed('Could not render Typst.\n\n${logs.toString()}');
  }

  Future<void> _generateThumbnail(String pdfPath, String buildDir) async {
    try {
      final doc = await PdfDocument.openFile(pdfPath);
      final page = doc.pages[0];
      const thumbW = 300.0;
      final thumbH = thumbW / (page.width / page.height);
      final image = await page.render(fullWidth: thumbW, fullHeight: thumbH);
      if (image == null) return;
      final uiImage = await image.createImage();
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      await File(
        '$buildDir${Platform.pathSeparator}thumb.png',
      ).writeAsBytes(byteData.buffer.asUint8List());
      image.dispose();
      await doc.dispose();
    } catch (e) {
      dev.log('Failed to generate thumbnail: $e', name: 'DocumentRenderService');
    }
  }

  Future<_ProcessResult> _tryRun(
    _RenderAttempt attempt,
    String workingDirectory,
    Map<String, String> environment,
  ) async {
    try {
      final result = await Process.run(
        attempt.executable,
        attempt.arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: true,
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

  Future<_RenderWorkspace> _prepareWorkspace(
    WhiskFile file, {
    String engine = 'latex',
  }) async {
    final projectRoot = file.projectRoot == null
        ? await Directory.systemTemp.createTemp('whisk-draft-$engine-')
        : Directory(file.projectRoot!);

    final config = file.projectRoot != null
        ? await WorkspaceConfig.load(file.projectRoot!)
        : WorkspaceConfig.defaultConfig;

    final whiskRoot = Directory(
      '${projectRoot.path}${Platform.pathSeparator}.whisk',
    );
    final cacheRoot = Directory(
      file.projectRoot != null
          ? '${whiskRoot.path}${Platform.pathSeparator}cache'
          : '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}cache',
    );
    await cacheRoot.create(recursive: true);

    final buildRoot = Directory(
      '${whiskRoot.path}${Platform.pathSeparator}build${Platform.pathSeparator}$engine',
    );
    await buildRoot.create(recursive: true);

    final extension = switch (engine) {
      'typst' => '.typ',
      _ => '.tex',
    };
    final sourcePath = file.projectRoot == null
        ? '${projectRoot.path}${Platform.pathSeparator}main$extension'
        : file.path;
    final entrypoint = _relativeToProject(
      sourcePath: sourcePath,
      projectRoot: projectRoot.path,
    );

    final env = <String, String>{
      'WHISK_CACHE_DIR': cacheRoot.path,
      'TYPST_PACKAGE_CACHE': '${cacheRoot.path}${Platform.pathSeparator}typst',
      'TMPDIR': cacheRoot.path,
      'TEMP': cacheRoot.path,
      'TMP': cacheRoot.path,
    };

    final fontconfigFile = File(
      '${cacheRoot.path}${Platform.pathSeparator}fontconfig.conf',
    );
    if (!await fontconfigFile.exists()) {
      await fontconfigFile.writeAsString(
        '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts:dtd:config:1.0">\n<fontconfig/>\n',
      );
    }
    env['FONTCONFIG_FILE'] = fontconfigFile.path;
    if (engine == 'latex') {
      env.addAll({
        'TEXMFVAR': '${cacheRoot.path}${Platform.pathSeparator}texmf-var',
        'TEXMFCONFIG': '${cacheRoot.path}${Platform.pathSeparator}texmf-config',
      });
    }

    return _RenderWorkspace(
      projectRoot: projectRoot,
      buildRoot: buildRoot,
      cacheRoot: cacheRoot,
      sourcePath: sourcePath,
      entrypoint: entrypoint,
      buildArgument: buildRoot.path,
      environment: env,
      config: config,
    );
  }

  String _relativeToProject({
    required String sourcePath,
    required String projectRoot,
  }) {
    final normalizedRoot = projectRoot.endsWith(Platform.pathSeparator)
        ? projectRoot
        : '$projectRoot${Platform.pathSeparator}';
    if (!sourcePath.startsWith(normalizedRoot)) {
      return sourcePath;
    }

    return sourcePath.substring(normalizedRoot.length);
  }
}

class _RenderWorkspace {
  const _RenderWorkspace({
    required this.projectRoot,
    required this.buildRoot,
    required this.cacheRoot,
    required this.sourcePath,
    required this.entrypoint,
    required this.buildArgument,
    required this.environment,
    required this.config,
  });

  final Directory projectRoot;
  final Directory buildRoot;
  final Directory cacheRoot;
  final String sourcePath;
  final String entrypoint;
  final String buildArgument;
  final Map<String, String> environment;
  final WorkspaceConfig config;
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
