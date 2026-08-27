import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'web_download/web_clipboard.dart';

/// Copies [text] to the system clipboard.
///
/// On web this uses the legacy `execCommand('copy')` path instead of
/// Flutter's normal [Clipboard.setData] — the async Clipboard API it relies
/// on is restricted by browsers to secure contexts (HTTPS/localhost), so on
/// a plain-HTTP LAN deployment (e.g. http://192.168.x.x:8079) every "Copy"
/// button across every feature would silently do nothing.
///
/// Returns true if the copy succeeded.
Future<bool> copyToClipboard(String text) async {
  if (kIsWeb) {
    return webExecCommandCopy(text);
  }
  await Clipboard.setData(ClipboardData(text: text));
  return true;
}
