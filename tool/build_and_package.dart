import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final versionMatch = RegExp(r'version:\s*(\S+)').firstMatch(pubspec);
  if (versionMatch == null) {
    stderr.writeln('Could not read version from pubspec.yaml');
    exit(1);
  }

  final fullVersion = versionMatch.group(1)!;
  final version = fullVersion.split('+')[0];
  final buildNumber = fullVersion.split('+').length > 1 ? fullVersion.split('+')[1] : '1';

  stdout.writeln('Version: $version (build $buildNumber)');

  // Update Inno Setup script
  final issFile = File('installer/whisk.iss');
  var issContent = issFile.readAsStringSync();
  issContent = issContent.replaceAll(
    RegExp(r'#define MyAppVersion ".*"'),
    '#define MyAppVersion "$version"',
  );
  issFile.writeAsStringSync(issContent);
  stdout.writeln('Updated installer/whisk.iss with version $version');

  // Build Flutter Windows release
  stdout.writeln('Building Flutter Windows release...');
  final buildResult = Process.runSync('flutter', [
    'build', 'windows',
    '--build-name', version,
    '--build-number', buildNumber,
  ], runInShell: true);

  stdout.write(buildResult.stdout);
  stderr.write(buildResult.stderr);

  if (buildResult.exitCode != 0) {
    stderr.writeln('Flutter build failed');
    exit(1);
  }

  stdout.writeln('Build successful!');
  stdout.writeln('Output: build/windows/x64/runner/Release/whisk.exe');
  stdout.writeln('Run Inno Setup Compiler on installer/whisk.iss to create the installer.');
}
