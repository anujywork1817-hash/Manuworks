import 'dart:html' as html;

/// Copies [text] to the clipboard using the legacy `execCommand('copy')`
/// path via a temporary offscreen textarea, instead of the async Clipboard
/// API (`navigator.clipboard.writeText`).
///
/// Why: Chrome (and other browsers) restrict the async Clipboard API to
/// "secure contexts" — HTTPS or localhost. This app is often reached over
/// plain HTTP on a LAN dev server (e.g. http://192.168.x.x:8079), which is
/// not a secure context, so Flutter's Clipboard.setData silently does
/// nothing there. execCommand('copy') has no such restriction.
///
/// Returns true if the copy command reported success.
bool webExecCommandCopy(String text) {
  final textarea = html.TextAreaElement()
    ..value = text
    ..style.position = 'fixed'
    ..style.left = '-9999px'
    ..style.top = '0'
    ..readOnly = true;
  html.document.body!.append(textarea);
  textarea.select();
  textarea.setSelectionRange(0, text.length);
  bool ok = false;
  try {
    ok = html.document.execCommand('copy');
  } catch (_) {
    ok = false;
  }
  textarea.remove();
  return ok;
}
