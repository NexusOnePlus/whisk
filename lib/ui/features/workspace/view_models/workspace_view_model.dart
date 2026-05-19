import 'package:flutter/foundation.dart';
import 'package:whisk/data/repositories/environment_catalog.dart';
import 'package:whisk/data/services/document_render_service.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/render_result.dart';
import 'package:whisk/domain/models/whisk_file.dart';

class WorkspaceViewModel extends ChangeNotifier {
  WorkspaceViewModel({
    EnvironmentCatalog catalog = const EnvironmentCatalog(),
    this._renderService = const DocumentRenderService(),
    WhiskFile? initialFile,
  }) : _environments = catalog.listEnvironments() {
    _activeFile = initialFile ?? _fileForEnvironment(_environments.first);
  }

  final DocumentRenderService _renderService;
  final List<EnvironmentKind> _environments;
  late WhiskFile _activeFile;
  int _selectedEnvironmentIndex = 0;
  RenderResult _renderResult = const RenderResult.idle();

  List<EnvironmentKind> get environments => List.unmodifiable(_environments);
  int get selectedEnvironmentIndex => _selectedEnvironmentIndex;
  EnvironmentKind get selectedEnvironment =>
      _environments[_selectedEnvironmentIndex];
  WhiskFile get activeFile => _activeFile;
  RenderResult get renderResult => _renderResult;

  void selectEnvironment(int index) {
    if (index == _selectedEnvironmentIndex) return;
    if (index < 0 || index >= _environments.length) return;

    _selectedEnvironmentIndex = index;
    _activeFile = _fileForEnvironment(_environments[index]);
    _renderResult = const RenderResult.idle();
    notifyListeners();
  }

  void updateActiveContent(String content) {
    if (content == _activeFile.content) return;
    _activeFile = _activeFile.copyWith(content: content, isDirty: true);
    notifyListeners();
  }

  Future<void> renderActiveFile() async {
    if (_renderResult.isRendering) return;

    _renderResult = const RenderResult.rendering();
    notifyListeners();

    _renderResult = await _renderService.render(
      environmentId: selectedEnvironment.id,
      file: _activeFile,
    );
    notifyListeners();
  }

  WhiskFile _fileForEnvironment(EnvironmentKind environment) {
    return WhiskFile(
      path: 'sample/${environment.id}${environment.extension}',
      name: '${environment.id}${environment.extension}',
      extension: environment.extension,
      content: environment.sample,
    );
  }
}
