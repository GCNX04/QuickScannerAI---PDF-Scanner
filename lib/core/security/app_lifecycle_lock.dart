import 'package:flutter/widgets.dart';

import 'app_lock_service.dart';

/// Locks the app when it leaves the foreground (after user enabled app lock).
class AppLifecycleLock extends StatefulWidget {
  const AppLifecycleLock({super.key, required this.child});

  final Widget child;

  @override
  State<AppLifecycleLock> createState() => _AppLifecycleLockState();
}

class _AppLifecycleLockState extends State<AppLifecycleLock> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AppLockService.instance.lockForBackground();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
