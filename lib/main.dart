import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sotong_ware_control/app.dart';
import 'package:sotong_ware_control/firebase_options.dart';
import 'package:sotong_ware_control/services/auth_runtime_config.dart';
import 'package:sotong_ware_control/services/auth_service.dart';
import 'package:sotong_ware_control/services/browser_json_download_service.dart';
import 'package:sotong_ware_control/state/control_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureBrowserJsonDownloadRegistered();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final controlState = ControlState();
  await controlState.initialize();

  final authService = AuthService();
  await AuthRuntimeConfig.ensureLoaded();
  runApp(
    SotongWareControlApp(controlState: controlState, authService: authService),
  );
}
