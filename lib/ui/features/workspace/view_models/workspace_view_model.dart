import 'package:flutter/foundation.dart';
import 'package:whisk/data/repositories/environment_catalog.dart';
import 'package:whisk/domain/models/environment_kind.dart';
import 'package:whisk/domain/models/whisk_file.dart';

class WorkspaceViewModel extends ChangeNotifier {
  WorkspaceViewModel({EnvironmentCatalog catalog = const EnvironmentCatalog()})
    : _environments = catalog.listEnvironments() {
    _activeFile = _fileForEnvironment(_environments.first);
  }

  final List<EnvironmentKind> _environments;
  late WhiskFile _activeFile;
  int _selectedEnvironmentIndex = 0;

  List<EnvironmentKind> get environments => List.unmodifiable(_environments);
  int get selectedEnvironmentIndex => _selectedEnvironmentIndex;
  EnvironmentKind get selectedEnvironment =>
      _environments[_selectedEnvironmentIndex];
  WhiskFile get activeFile => _activeFile;

  void selectEnvironment(int index) {
    if (index == _selectedEnvironmentIndex) return;
    if (index < 0 || index >= _environments.length) return;

    _selectedEnvironmentIndex = index;
    _activeFile = _fileForEnvironment(_environments[index]);
    notifyListeners();
  }

  void updateActiveContent(String content) {
    if (content == _activeFile.content) return;
    _activeFile = _activeFile.copyWith(content: content, isDirty: true);
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
