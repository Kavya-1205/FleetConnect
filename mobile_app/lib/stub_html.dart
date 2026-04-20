// Stub for dart:html — used only on non-web platforms so the import
// conditional `dart:html if (dart.library.io) 'stub_html.dart'` works.

class Blob {
  Blob(List<dynamic> data, [String? type]);
}

class AnchorElement {
  AnchorElement({String? href});
  void setAttribute(String name, String value) {}
  void click() {}
  void remove() {}
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}
