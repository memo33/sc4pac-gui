import 'dart:io' show Platform, Directory;
import 'package:win32_registry/win32_registry.dart';

// from https://github.com/llfbandit/app_links/blob/master/doc/README_windows.md
Future<void> registerProtocolScheme(String scheme, String? profilesDir) async {
  if (!Platform.isWindows) {
    return;
  }
  String appPath = Platform.resolvedExecutable;

  String protocolRegKey = 'Software\\Classes\\$scheme';
  RegistryValue protocolRegValue = const RegistryValue(
    'URL Protocol',
    RegistryValueType.string,
    '',
  );
  String protocolCmdRegKey = 'shell\\open\\command';
  RegistryValue protocolCmdRegValue = RegistryValue(
    '',
    RegistryValueType.string,
    [
      '"$appPath" "%1"',
      if (profilesDir != null)
        '"--profiles-dir" "${Directory(profilesDir).absolute.path}"'
    ].join(' '),
  );

  final regKey = Registry.currentUser.createKey(protocolRegKey);
  regKey.createValue(protocolRegValue);
  regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);
}
