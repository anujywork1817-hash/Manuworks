/// Non-web platforms never call this — [copyToClipboard] only reaches here
/// behind a `kIsWeb` check, and mobile/desktop use Flutter's own Clipboard.
bool webExecCommandCopy(String text) => false;
