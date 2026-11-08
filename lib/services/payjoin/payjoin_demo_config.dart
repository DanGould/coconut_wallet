import 'dart:io';

import 'package:coconut_wallet/services/payjoin/payjoin_config.dart';

/// Payjoin settings for a local test stack, given at build time:
///
///     --dart-define=PAYJOIN_DIRECTORY=https://localhost:60480
///     --dart-define=PAYJOIN_OHTTP_RELAYS=http://localhost:60481,http://localhost:60482
///     --dart-define=PAYJOIN_DIRECTORY_CERT=/path/to/directory-cert.der
///
/// Without them the defaults apply. On loopback each port counts as its own
/// operator, so a directory and relays on one machine can serve a session.
Future<PayjoinConfig> payjoinConfigFromDefines() async {
  const directory = String.fromEnvironment('PAYJOIN_DIRECTORY');
  const relays = String.fromEnvironment('PAYJOIN_OHTTP_RELAYS');
  const certPath = String.fromEnvironment('PAYJOIN_DIRECTORY_CERT');
  if (directory.isEmpty && relays.isEmpty) return PayjoinConfig.defaults;
  return PayjoinConfig(
    directoryUrls: directory.isEmpty ? PayjoinConfig.defaults.directoryUrls : [directory],
    ohttpRelayUrls: relays.isEmpty ? PayjoinConfig.defaults.ohttpRelayUrls : relays.split(','),
    directoryCertificate: certPath.isEmpty ? null : await File(certPath).readAsBytes(),
  );
}
