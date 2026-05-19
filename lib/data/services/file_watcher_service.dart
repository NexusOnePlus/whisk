import 'dart:async';
import 'dart:io';
import 'package:watcher/watcher.dart';

class FileWatcherService {
  const FileWatcherService();

  Stream<WatchEvent> watchDirectory(String path) {
    if (!Directory(path).existsSync()) {
      return const Stream.empty();
    }
    return DirectoryWatcher(path).events;
  }
}
