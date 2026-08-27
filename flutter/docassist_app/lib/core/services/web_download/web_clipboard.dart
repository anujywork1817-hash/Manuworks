// Conditional export — see web_download.dart for the same pattern.
export 'web_clipboard_stub.dart' if (dart.library.html) 'web_clipboard_web.dart';
