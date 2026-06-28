import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'channel_ml_service.dart';
import 'ml_service.dart';

/// Single place to resolve the ML backend. Uses the native platform-channel
/// implementation; if no native handler is registered yet (pre-Phase-2 builds),
/// [ChannelMlService] degrades gracefully to "unavailable" so UI shows
/// coming-soon states instead of crashing. Swap to [StubMlService] in tests.
final mlServiceProvider = Provider<MlService>((_) => const ChannelMlService());

/// Reports whether on-device ML is actually wired on this device/build.
final mlAvailableProvider = FutureProvider<bool>((ref) {
  return ref.watch(mlServiceProvider).isAvailable();
});
