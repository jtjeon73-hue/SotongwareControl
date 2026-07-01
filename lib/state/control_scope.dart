import 'package:flutter/material.dart';

import 'control_state.dart';

class ControlScope extends InheritedNotifier<ControlState> {
  const ControlScope({
    super.key,
    required ControlState super.notifier,
    required super.child,
  });

  static ControlState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ControlScope>();
    assert(scope != null, 'ControlScope not found in widget tree');
    return scope!.notifier!;
  }

  static ControlState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ControlScope>()?.notifier;
  }
}
