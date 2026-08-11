import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationForegroundTask());
}

class LocationForegroundTask extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // No-op: socket handling is done by the app process.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Keep the foreground task alive; add heartbeat logic if needed.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Clean up resources if needed.
  }

  @override
  void onReceiveData(Object data) {
    // Handle messages from the UI if required.
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}
