import 'dart:io';
import "package:path/path.dart" as paths;

Directory getPackageRoot() {
  Directory dir = Directory.current;
  try {
    while (
        dir.listSync().any((f) => f.path.endsWith("pubspec.yaml")) == false &&
            dir.path != "/") dir = dir.parent;
  } catch (e) {
    throw new Exception(
        "Error while trying to find pubspec.yaml from ${dir.path}:\n$e");
  }
  return dir;
}

String getPackageRootPath() => getPackageRoot().path + paths.separator;

String resolvePath(Uri uri) {
  switch (uri.scheme) {
    case "file":
      return uri.path;
      break;
    case "package":
      String packageName = uri.pathSegments.first;
      File packages = new File("${getPackageRootPath()}.packages");
      Uri pathUri;
      try {
        String packageNameLine = packages
            .readAsLinesSync()
            .firstWhere((line) => line.startsWith("$packageName:"));
        pathUri = Uri
            .parse(packageNameLine.substring(packageNameLine.indexOf(":") + 1));
      } catch (e) {
        throw new MissingPackageException(uri);
      }
      return paths.absolute(
          pathUri.path, paths.joinAll(uri.pathSegments.sublist(1)));
      break;
  }
}

class MissingPackageException implements Exception {
  Uri uri;
  MissingPackageException(this.uri);

  String toString() =>
      "Could not find the path for the package ${paths.prettyUri(uri)}. Already tried running 'pub get'?";
}
