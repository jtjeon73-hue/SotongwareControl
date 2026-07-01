import 'package:flutter/material.dart';
import 'package:sotong_ware_control/app.dart';
import 'package:sotong_ware_control/state/control_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controlState = ControlState();
  await controlState.initialize();
  runApp(SotongWareControlApp(controlState: controlState));
}
