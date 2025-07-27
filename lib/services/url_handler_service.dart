// lib/services/url_handler_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/warning_dialog_screen.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';




class UrlHandlerService {
  static const String API_BASE_URL = 'http://10.62.48.185:5000';
  static const String API_CHECK_ENDPOINT = '/predict';

  // Check if URL is safe
  static Future<Map<String, dynamic>> checkUrlSafety(String url) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL$API_CHECK_ENDPOINT'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        return {
          'success': true,
          'data': result,
        };
      } else {
        return {
          'success': false,
          'error': 'API returned status code: ${response.statusCode}',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'error': 'Network error',
        'message': 'Could not connect to the API.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Unexpected error',
        'message': e.toString(),
      };
    }
  }

  // Determine if URL is safe based on API response
  static bool isUrlSafe(Map<String, dynamic> apiResponse) {
    if (!apiResponse['success']) return false;

    final data = apiResponse['data'];
    final predictedLabel = data['predicted_label']?.toString().toLowerCase();
    return predictedLabel == 'benign';
  }

  // Open URL in preferred browser
  static Future<void> openInBrowser(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedPackage = prefs.getString('preferred_browser');

    if (selectedPackage == null || selectedPackage.isEmpty) {
      // Fallback to default browser
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
      return;
    }

    try {
      const platform = MethodChannel('com.example.safelink/browser');
      await platform.invokeMethod('openInBrowser', {
        'url': url,
        'package': selectedPackage,
      });
    } on PlatformException catch (e) {
      print("Failed to open browser: ${e.message}");
      // Fallback to default browser
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    }
  }

  // Main URL processing logic
  static Future<void> processIncomingUrl(BuildContext context, String url) async {
    try {
      // Resolve redirects first
      final resolvedUrl = await resolveRedirect(url);

      // Check URL safety
      final apiResult = await checkUrlSafety(resolvedUrl);

      if (isUrlSafe(apiResult)) {
        // Safe URL - open directly in browser
        await openInBrowser(resolvedUrl);
      } else {
        // Unsafe URL - show warning dialog
        if (context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WarningDialogScreen(
                url: resolvedUrl,
                apiResult: apiResult,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print("Error processing URL: $e");
      // Show error or fallback behavior
    }
  }

  // Helper method to resolve redirects
  static Future<String> resolveRedirect(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; SafeLinkApp/1.0)',
        },
      ).timeout(const Duration(seconds: 10));

      return response.request?.url.toString() ?? url;
    } catch (e) {
      print("Error resolving redirect: $e");
      return url;
    }
  }

  static Future<void> processQuickCheckInBackground(String url) async {
    // 1. Show notification
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    await flutterLocalNotificationsPlugin.show(
      1,
      'SafeLink',
      'Checking link silently...',
      const NotificationDetails(
        android: AndroidNotificationDetails('silent', 'Silent Check',
            importance: Importance.low, priority: Priority.low),
      ),
    );

    // 2. Resolve & check
    final resolved = await resolveRedirect(url);
    final result = await checkUrlSafety(resolved);

    if (isUrlSafe(result)) {
      await openInBrowser(resolved);
    } else {
      // Show dialog overlay (optional — needs more platform channel to show over other app)
      // or push a system-level warning notification
    }
  }

  Future<void> requestOverlayPermissionIfNeeded() async {
    final isGranted = await FlutterOverlayWindow.isPermissionGranted();

    if (!isGranted) {
      await FlutterOverlayWindow.requestPermission();
    }
  }

}