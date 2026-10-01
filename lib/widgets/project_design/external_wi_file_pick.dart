import 'external_wi_file_pick_stub.dart'
    if (dart.library.html) 'external_wi_file_pick_web.dart' as impl;

/// Browser-safe JSON file pick (no absolute path uploaded to server).
Future<String?> pickExternalWiJsonText() => impl.pickExternalWiJsonTextImpl();
