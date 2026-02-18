// Minimal io stub for web builds to avoid importing dart:io
class Directory {
  final String path;
  Directory(this.path);

  Future<bool> exists() async => false;
  Future<void> create({bool recursive = false}) async {}
  Future<void> delete({bool recursive = false}) async {}
}

class File {
  final String path;
  File(this.path);

  Future<bool> exists() async => false;
  Future<void> writeAsBytes(List<int> bytes) async {
    throw UnsupportedError('File I/O is not supported on web');
  }

  Future<List<int>> readAsBytes() async {
    throw UnsupportedError('File I/O is not supported on web');
  }

  Future<void> delete() async {}
  
  Future<String> copy(String newPath) async {
    throw UnsupportedError('File I/O is not supported on web');
  }
}
