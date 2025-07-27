import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart' as overlay;
import 'package:safelink/services/url_handler_service.dart';

final FlutterLocalNotificationsPlugin _notifications =
FlutterLocalNotificationsPlugin();

//import 'package:flutter_overlay_window/flutter_overlay_window.dart';

Future<void> showFloatingOverlay(String url, Map<String, dynamic> result) async {
  final granted = await overlay.FlutterOverlayWindow.isPermissionGranted();
  if (!granted) {
    await overlay.FlutterOverlayWindow.requestPermission();
  }

  await overlay.FlutterOverlayWindow.showOverlay(
    overlayContent: "⚠️ Suspicious Link\n$url\nTap to dismiss.",
    height: overlay.WindowSize.fullCover,
    width: overlay.WindowSize.matchParent,
    alignment: overlay.OverlayAlignment.center,
    //visibility: NotificationVisibility.visibilityPublic,
    enableDrag: false,
    flag: overlay.OverlayFlag.defaultFlag,
  );
}


Future<void> handleSilentCheck(String url) async {
  try {
    // Init notification system
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
    InitializationSettings(android: androidInit);

    await _notifications.initialize(initSettings);

    // Notify while checking
    await _notifications.show(
      1001,
      'SafeLink',
      'Checking link in background...',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'safelink_channel_v2', // Consistent with AndroidManifest if needed
          'SafeLink Background Check',
          // importance: Importance.defaultImportance,
          // priority: Priority.defaultPriority,
          importance: Importance.max,      // ✅ Push to top
          priority: Priority.high,         // ✅ Top of list
          playSound: true,                 // ✅ With sound (if allowed)
          enableVibration: true,
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 200));

    // Resolve redirects (e.g., bit.ly)
    final resolvedUrl = await UrlHandlerService.resolveRedirect(url);

    // Check safety with API
    final result = await UrlHandlerService.checkUrlSafety(resolvedUrl);

    // Show result
    if (UrlHandlerService.isUrlSafe(result)) {
      await UrlHandlerService.openInBrowser(resolvedUrl);
    } else {
      // ❗ Enable below if overlay dialog is ready
      showFloatingOverlay(resolvedUrl, result);

      // TEMP fallback → show final warning notification
      await _notifications.show(
        1002,
        '⚠️ Potentially Unsafe Link',
        resolvedUrl,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'safelink_alert_channel_v2',
            'SafeLink Background Check',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,                 // ✅ With sound (if allowed)
            enableVibration: true,
          ),
        ),
      );
    }
  } catch (e) {
    await _notifications.show(
      9999,
      'SafeLink Error',
      'Something went wrong during background check.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'safelink_lol_channel_2',
          'SafeLink Background Check',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,                 // ✅ With sound (if allowed)
          enableVibration: true,
        ),
      ),
    );
    print('❌ Error in handleSilentCheck: $e');
  }
}
