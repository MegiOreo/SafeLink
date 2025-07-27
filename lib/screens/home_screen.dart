import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
as mlkit;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:safelink/constants/app_colors.dart';
import 'package:safelink/main.dart';
import 'package:safelink/services/url_handler_service.dart';
import 'package:safelink/screens/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// For MethodCall and MethodChannel
import 'package:safelink/screens/qr_scanner.dart';

import 'safelink_chatbot.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  String? _qrResult;
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String? _finalUrl;


  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  late FlutterLocalNotificationsPlugin _notificationsPlugin;

  // API Configuration
  static const String API_BASE_URL = 'http://10.62.48.185:5000';
  static const String API_CHECK_ENDPOINT = '/predict';

  Uint8List? _selectedBrowserIcon;
  String? _predictedLabel;
  String? _selectedBrowserName;




  Future<void> _loadSelectedBrowserIcon() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedPackage = prefs.getString('preferred_browser');
    if (selectedPackage == null) return;

    const platform = MethodChannel('com.example.safelink/browser');

    try {
      final List<dynamic> result =
      await platform.invokeMethod('getInstalledBrowsers');

      final List<Map<String, String>> browsers =
      result.map((e) => Map<String, String>.from(e as Map)).toList();

      final matched = browsers.firstWhere(
            (browser) => browser['package'] == selectedPackage,
        orElse: () => {},
      );

      if (matched.isNotEmpty && matched['icon'] != null) {
        // setState(() {
        //   _selectedBrowserIcon = base64Decode(matched['icon']!);
        // });
        setState(() {
          _selectedBrowserIcon = matched['icon'] != null
              ? base64Decode(matched['icon']!)
              : null;
          _selectedBrowserName = matched['name'];
        });

      }
    } on PlatformException catch (e) {
      print("Failed to load browser icon: ${e.message}");
    }
  }

  Future<void> openURLinBrowser() async {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      await UrlHandlerService.openInBrowser(url);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    //_initializeBackgroundServices();
    _loadSelectedBrowserIcon();
    _cleanupOldImages();
    //_promptSetAsDefaultIfFirstTime();
    _appLinks =AppLinks();
    //_listenForIncomingLinks(); //start edit
    //_appLinks = AppLinks();
    _promptSetAsDefaultIfNeeded();
  }

  // void _listenForIncomingLinks() {
  //   _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
  //     if (uri != null && _isValidUrl(uri.toString())) {
  //       _handleIncomingLinkSilently(uri.toString()); // 👉 method baru
  //     }
  //   }, onError: (err) {
  //     print("AppLinks error: $err");
  //   });
  // }

  // Future<void> _handleIncomingLinkSilently(String url) async {
  //   // 1. Tunjuk notifikasi "Checking..."
  //   _showCheckingNotification();
  //
  //   // 2. Resolve dan check dengan API
  //   final resolved = await _resolveRedirect(url);
  //   final result = await _checkUrlWithAPI(resolved);
  //
  //   // 3. If benign → buka browser
  //   if (result['success'] && result['data']?['predicted_label'] == 'benign') {
  //     await UrlHandlerService.openInBrowser(resolved);
  //   } else {
  //     // 4. If unsafe → tunjuk overlay dialog
  //     _showFloatingDialog(result, resolved);
  //   }
  // }

  // void _showCheckingNotification() async {
  //   const AndroidNotificationDetails androidDetails =
  //   AndroidNotificationDetails(
  //     'safelink_channel',
  //     'SafeLink Notifications',
  //     importance: Importance.defaultImportance,
  //     priority: Priority.defaultPriority,
  //     showWhen: false,
  //   );
  //
  //   const NotificationDetails notificationDetails =
  //   NotificationDetails(android: androidDetails);
  //
  //   await _notificationsPlugin.show(
  //     0,
  //     'SafeLink',
  //     'Checking the link in background...',
  //     notificationDetails,
  //   );
  // }

  // void _showFloatingDialog(Map<String, dynamic> result, String url) {
  //   // final context = navigatorKey.currentContext; // From global navigatorKey
  //   // if (context == null) return;
  //   BuildContext? context = navigatorKey.currentContext ??
  //       navigatorKey.currentState?.overlay?.context;
  //
  //   if (context == null) {
  //     print("❌ Cannot show dialog: context is null.");
  //     return;
  //   }
  //
  //   final formatted = _formatApiResult(result);
  //
  //   showDialog(
  //     context: context,
  //     barrierColor: Colors.black.withOpacity(0.3),
  //     barrierDismissible: false,
  //     builder: (_) => Dialog(
  //       backgroundColor: Colors.white.withOpacity(0.95),
  //       insetPadding: const EdgeInsets.all(24),
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       child: Padding(
  //         padding: const EdgeInsets.all(16),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             const Text('⚠️ Unsafe Link Detected',
  //                 style: TextStyle(fontWeight: FontWeight.bold)),
  //             const SizedBox(height: 12),
  //             Text(
  //               formatted,
  //               style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
  //             ),
  //             const SizedBox(height: 16),
  //             ElevatedButton.icon(
  //               icon: const Icon(Icons.open_in_browser),
  //               label: const Text("Open Anyway"),
  //               style: ElevatedButton.styleFrom(
  //                 backgroundColor: Colors.red.shade600,
  //                 foregroundColor: Colors.white,
  //               ),
  //               onPressed: () async {
  //                 Navigator.pop(context);
  //                 await UrlHandlerService.openInBrowser(url);
  //               },
  //             ),
  //             const SizedBox(height: 8),
  //             TextButton(
  //               child: const Text("Cancel"),
  //               onPressed: () => Navigator.pop(context),
  //             )
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }





  Future<void> _promptSetAsDefaultIfNeeded() async {
    const channel = MethodChannel('com.example.safelink/browser');

    bool isDefault = false;
    try {
      isDefault = await channel.invokeMethod<bool>('isDefaultBrowser') ?? false;
    } on PlatformException catch (e) {
      debugPrint('Could not determine default browser: ${e.message}');
    }

    if (isDefault) return; // already default – nothing to do

    // Show the same beautiful dialog you already have
    await Future.delayed(const Duration(milliseconds: 600)); // let UI settle
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DefaultBrowserDialog(onOpenSettings: () async {
        Navigator.of(context).pop();
        try {
          await channel.invokeMethod('openDefaultAppSettings');
        } on PlatformException catch (e) {
          debugPrint('Failed to open settings: ${e.message}');
        }
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  // Initialize notifications
  void _initNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  // Cancel notification

  // API call to check URL safety
  Future<Map<String, dynamic>> _checkUrlWithAPI(String url) async {
    try {
      final response = await http
          .post(
        Uri.parse('$API_BASE_URL$API_CHECK_ENDPOINT'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'url': url,
        }),
      )
          .timeout(const Duration(seconds: 30));

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
          'message': response.body,
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timeout',
        'message': 'The API request took too long to respond',
      };
    } on SocketException {
      return {
        'success': false,
        'error': 'Network error',
        'message':
        'Could not connect to the API. Make sure the server is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Unexpected error',
        'message': e.toString(),
      }; //start
    }
  }

  // Check if URL is safe based on API response

  String _formatApiResult(Map<String, dynamic> apiResponse) {
    if (!apiResponse['success']) {
      return '❌ Error: ${apiResponse['error']}\n${apiResponse['message']}';
    }

    final data = apiResponse['data'];

    if (data.containsKey('predicted_label')) {
      final String predictedLabel = data['predicted_label'] ?? 'unknown';
      //final double? confidence = data['confidence']?.toDouble();
      //final Map<String, dynamic>? classProbs = data['class_probabilities'];

      // Determine if it's safe
      final bool isSafe = predictedLabel.toLowerCase() == 'benign';
      final String unshortenedUrl = data['unshortened_url'] ?? '';
      final String originalUrl = data['original_url'] ?? '';


      String result = isSafe ? '✅ SAFE LINK' : '⚠️ POTENTIALLY UNSAFE LINK';
      result += '\nPrediction: ${predictedLabel.toUpperCase()}';

      if(unshortenedUrl!=originalUrl)
        result += '\n\n🔗 Url Scanned:\n$originalUrl';

      // if (confidence != null) {
      //   result += '\nConfidence: ${(confidence * 100).toStringAsFixed(1)}%';
      // }

      // if (classProbs != null) {
      //   result += '\n\nClass Probabilities:';
      //   classProbs.forEach((label, prob) {
      //     result +=
      //         '\n- ${label.toUpperCase()}: ${(prob * 100).toStringAsFixed(1)}%';
      //   });
      // }

      return result;
    } else {
      return '📊 API Response:\n${jsonEncode(data)}';
    }
  }

  // Pull to refresh - clear all values
  Future<void> _refreshAndClear() async {
    setState(() {
      _selectedImage = null;
      _qrResult = null;
      _urlController.clear();
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Page refreshed',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        duration: Duration(seconds: 2),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));
  }

  bool _showProceedButton = false;

  // Manual URL check (existing functionality)
  void _checkUrlManually() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      if (_isValidUrl(url)) {
        _processIncomingUrl(url);
      } else {
        setState(() {
          _qrResult =
          '❌ Please enter a valid URL (must start with http:// or https://)';
          _showProceedButton = false;
        });
      }
    } else {
      setState(() {
        _qrResult = '❌ Please enter a URL to check';
      });
    }
  }

  Color get proceedButtonColor {
    if (_predictedLabel == 'benign') {
      return Colors.teal.shade600;
    } else {
      return Colors.red.shade700;
    }
  }

  // Process incoming URL (for manual checks)
  void _processIncomingUrl(String url) async {
    setState(() {
      _isLoading = true;
      _qrResult = "🔍 Resolving redirects...";
    });

    try {
      final resolvedUrl = await _resolveRedirect(url);
      setState(() {
        _qrResult = '🔍 Checking link safety...';
        _urlController.text = resolvedUrl;
      });

      final apiResult = await _checkUrlWithAPI(resolvedUrl);
      setState(() {
        _qrResult = _formatApiResult(apiResult);
        _showProceedButton = true; //apiResult['success'];
        _predictedLabel =
            apiResult['data']?['predicted_label']?.toString().toLowerCase();
        _finalUrl = apiResult['data']?['unshortened_url'];
      });
      _showResultDialog();
    } catch (e) {
      setState(() {
        _qrResult = '❌ Error processing link: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _qrResult = null;
        _isLoading = true;
      });

      final inputImage = mlkit.InputImage.fromFilePath(image.path);
      final barcodeScanner =
      mlkit.BarcodeScanner(formats: [mlkit.BarcodeFormat.qrCode]);

      try {
        final List<mlkit.Barcode> barcodes =
        await barcodeScanner.processImage(inputImage);
        if (barcodes.isNotEmpty) {
          final qrCodeValue =
              barcodes.first.rawValue ?? 'QR code found but unreadable';
          print("QR Code Value: $qrCodeValue");

          if (_isValidUrl(qrCodeValue)) {
            setState(() {
              _qrResult = '🔍 Resolving redirects...';
            });

            final resolvedUrl = await _resolveRedirect(qrCodeValue);
            print("Resolved URL: $resolvedUrl");

            setState(() {
              _qrResult = '🔍 Checking link safety...';
              _urlController.text = resolvedUrl;
            });

            final apiResult = await _checkUrlWithAPI(resolvedUrl);
            setState(() {
              _qrResult = _formatApiResult(apiResult);
              _showProceedButton = true; //apiResult['success'];
              _predictedLabel = apiResult['data']?['predicted_label']
                  ?.toString()
                  .toLowerCase();
            });
            _showResultDialog();
          } else {
            setState(() {
              _qrResult = '❌ QR code does not contain a valid URL';
            });
          }
        } else {
          setState(() {
            _qrResult = '❌ No QR code found in the image';
          });
        }
      } catch (e) {
        print("Error processing image: $e");
        setState(() {
          _qrResult = '❌ Error processing image: $e';
        });
      } finally {
        barcodeScanner.close();
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _resolveRedirect(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; SafeLinkApp/1.0)',
        },
      ).timeout(const Duration(seconds: 10));

      print("Final URL: ${response.request?.url}");
      return response.request?.url.toString() ?? url;
    } catch (e) {
      print("Error resolving redirect: $e");
      return url;
    }
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  Future<File> _saveImageTemporarily(Uint8List imageBytes) async {
    try {
      final appDir = await Directory('${Directory.systemTemp.path}/app_images')
          .create(recursive: true);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${appDir.path}/scanned_qr_$timestamp.png');

      // Write the file synchronously to ensure it's completely written
      await file.writeAsBytes(imageBytes);

      // Verify the file was written successfully
      if (await file.exists() && await file.length() > 0) {
        print(
            "Image saved successfully: ${file.path}, Size: ${await file.length()} bytes");
        return file;
      } else {
        throw Exception("Failed to save image properly");
      }
    } catch (e) {
      print("Error saving image: $e");
      rethrow;
    }
  }

  void _scanQR() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QRScannerScreen()),
    );

    if (result != null && result['result'] != null) {
      final scannedValue = result['result'] as String;

      // Process the image first, before URL processing
      if (result['image'] != null) {
        setState(() {
          _isLoading = true;
        });

        try {
          final image = result['image'] as Uint8List;
          final file = await _saveImageTemporarily(image);

          // Set the image immediately after saving
          setState(() {
            _selectedImage = XFile(file.path);
          });

          print("Image set in state: ${file.path}");
        } catch (e) {
          print("Error saving image: $e");
        }
      }

      // Now process the URL
      if (_isValidUrl(scannedValue)) {
        setState(() {
          _qrResult = "🔍 Resolving redirects...";
          _isLoading = true;
        });

        try {
          final resolved = await _resolveRedirect(scannedValue);
          setState(() {
            _qrResult = '🔍 Checking link safety...';
            _urlController.text = resolved;
            _showProceedButton = false;
          });

          final apiResult = await _checkUrlWithAPI(resolved);
          setState(() {
            _qrResult = _formatApiResult(apiResult);
            _showProceedButton = true;
            _predictedLabel =
                apiResult['data']?['predicted_label']?.toString().toLowerCase();
          });
          _showResultDialog();
        } catch (e) {
          setState(() {
            _qrResult = '❌ Error processing scanned URL: $e';
          });
        }
      } else {
        setState(() {
          _qrResult = '❌ Scanned QR code does not contain a valid URL';
        });
      }

      // Always set loading to false at the end
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cleanupOldImages() async {
    try {
      final appDir = Directory('${Directory.systemTemp.path}/app_images');
      if (await appDir.exists()) {
        final files = appDir.listSync();
        final now = DateTime.now();

        for (final file in files) {
          if (file is File && file.path.contains('scanned_qr_')) {
            final fileStat = await file.stat();
            final age = now.difference(fileStat.modified);

            // Delete files older than 1 hour
            if (age.inHours > 1) {
              await file.delete();
              print("Cleaned up old image: ${file.path}");
            }
          }
        }
      }
    } catch (e) {
      print("Error cleaning up old images: $e");
    }
  }

  // void _showResultDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: const Text('📊 Results'),
  //       content: SingleChildScrollView(
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             if (_selectedImage != null) ...[
  //               const Text(
  //                 'Image:',
  //                 style: TextStyle(fontWeight: FontWeight.w500),
  //               ),
  //               const SizedBox(height: 8),
  //               Container(
  //                 height: 200,
  //                 width: double.infinity,
  //                 decoration: BoxDecoration(
  //                   border: Border.all(color: Colors.grey.shade300),
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: ClipRRect(
  //                   borderRadius: BorderRadius.circular(8),
  //                   child: Image.file(
  //                     File(_selectedImage!.path),
  //                     fit: BoxFit.contain,
  //                   ),
  //                 ),
  //               ),
  //               const SizedBox(height: 16),
  //             ],
  //             if (_qrResult != null) ...[
  //               const Text(
  //                 'Scan Result:',
  //                 style: TextStyle(fontWeight: FontWeight.w500),
  //               ),
  //               const SizedBox(height: 8),
  //               Container(
  //                 width: double.infinity,
  //                 padding: const EdgeInsets.all(12),
  //                 decoration: BoxDecoration(
  //                   color: _qrResult!.contains('✅')
  //                       ? Colors.green.shade50
  //                       : _qrResult!.contains('⚠️')
  //                           ? Colors.red.shade50
  //                           : _qrResult!.contains('❌')
  //                               ? Colors.orange.shade50
  //                               : Colors.blue.shade50,
  //                   border: Border.all(
  //                     color: _qrResult!.contains('✅')
  //                         ? Colors.green.shade200
  //                         : _qrResult!.contains('⚠️')
  //                             ? Colors.red.shade200
  //                             : _qrResult!.contains('❌')
  //                                 ? Colors.orange.shade200
  //                                 : Colors.blue.shade200,
  //                   ),
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       _qrResult!,
  //                       style: const TextStyle(
  //                         fontFamily: 'monospace',
  //                         fontSize: 14,
  //                       ),
  //                     ),
  //                     if (_showProceedButton)
  //                       Container(
  //                         margin: const EdgeInsets.only(top: 16),
  //                         child: Row(
  //                           children: [
  //                             ElevatedButton(
  //                               onPressed: openURLinBrowser,
  //                               style: ElevatedButton.styleFrom(
  //                                 backgroundColor:
  //                                     proceedButtonColor, //Colors.teal.shade600,
  //                                 foregroundColor: Colors.white,
  //                                 shape: RoundedRectangleBorder(
  //                                   borderRadius: BorderRadius.circular(8),
  //                                 ),
  //                                 padding: const EdgeInsets.symmetric(
  //                                   horizontal: 12,
  //                                   vertical: 8,
  //                                 ),
  //                               ),
  //                               child: Row(
  //                                 mainAxisSize: MainAxisSize.min,
  //                                 children: [
  //                                   if (_selectedBrowserIcon != null)
  //                                     Padding(
  //                                       padding:
  //                                           const EdgeInsets.only(right: 6),
  //                                       child: Image.memory(
  //                                         _selectedBrowserIcon!,
  //                                         width: 20,
  //                                         height: 20,
  //                                       ),
  //                                     ),
  //                                   const Text('Open'),
  //                                 ],
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                       ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ],
  //         ),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Close'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.verified_user, size: 24, color: Colors.teal),
                  SizedBox(width: 8),
                  Text(
                    'Scan Result',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 1.2),
              if (_selectedImage != null) ...[
                const Text(
                  '📷 Scanned Image:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                ),
                const SizedBox(height: 20),
              ],
              if (_qrResult != null) ...[

                if (_finalUrl != null) ...[
                  //const SizedBox(height: 8),
                  const Text(
                    '🔗 Final URL:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _finalUrl!,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],

                // const SizedBox(height: 8),
                //
                // const Text(
                //   '🔍 Prediction:',
                //   style: TextStyle(fontWeight: FontWeight.w500),
                // ),

                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _qrResult!.contains('✅')
                        ? Colors.green.shade50
                        : _qrResult!.contains('⚠️')
                        ? Colors.red.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _qrResult!.contains('✅')
                          ? Colors.green.shade200
                          : _qrResult!.contains('⚠️')
                          ? Colors.red.shade200
                          : Colors.blue.shade200,
                    ),
                  ),
                  // child: Text(
                  //   _qrResult!,
                  //   style: const TextStyle(
                  //     fontFamily: 'monospace',
                  //     fontSize: 15,
                  //     fontWeight: FontWeight.w500,
                  //   ),
                  // ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _qrResult!.split('\n')[0] + '\n',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, // 🔥 bold for status line
                            fontSize: 15,
                          ),
                        ),
                        TextSpan(
                          text: _qrResult!.split('\n').skip(1).join('\n'),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                  ,
                ),
                const SizedBox(height: 16),

                //Brief explain what the prediction mean here and clickable learn more
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📘 What the results mean:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Benign: A normal, safe link with no known threats.\n'
                            '• Phishing: Attempts to steal sensitive data like passwords.\n'
                        //'• Defacement: Alters websites to display malicious or unauthorized content.\n'
                            '• Malware: Can install harmful software or viruses on your device.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                          child: const Text(
                            'Learn more →',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          //onTap: _openLearnMoreDialog,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => GeminiChatPage(urlStatus: _predictedLabel, // Pass your actual predicted label here
                                    url: _finalUrl,)//ChatPage()//GeminiChatPage(predictedLabel: _predictedLabel ?? 'benign'),
                              ),
                            );
                          }

                      ),
                    ],
                  ),
                ),


                const SizedBox(height: 16),
                if (_showProceedButton)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: openURLinBrowser,
                          icon: _selectedBrowserIcon != null
                              ? Image.memory(
                            _selectedBrowserIcon!,
                            width: 20,
                            height: 20,
                          )
                              : const Icon(Icons.open_in_browser),
                          label: const Text('Open Link'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: proceedButtonColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  //onPressed: () => Navigator.pop(context),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                    });
                  },
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _openSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );

    if (changed == true) {
      _loadSelectedBrowserIcon(); // fetch new icon & setState
    }
  }

  @override
  Widget build(BuildContext context) {
    // Normal UI for manual scanning
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SafeLink',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            // onPressed: () {
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(builder: (_) => const SettingsScreen()),
            //   );
            // },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAndClear,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // URL Input Section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔗 Enter URL to Check',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          hintText: 'https://example.com',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _checkUrlManually,
                          icon: _isLoading
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                              : const Icon(Icons.security, color: Colors.white,),
                          label: Text(_isLoading ? 'Checking...' : 'Check URL'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // QR Code Section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📱 Scan QR Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _pickImage,
                              icon: const Icon(Icons.photo_library, color: Colors.white,),
                              label: const Text('Gallery'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _scanQR,
                              icon: const Icon(Icons.qr_code_scanner, color: Colors.white,),
                              label: const Text('Live Scan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              //if (_selectedBrowserName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _openSettings, // ➡️ open browser settings screen
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _selectedBrowserIcon != null
                                ? Image.memory(
                              _selectedBrowserIcon!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            )
                                : Container(
                              width: 40,
                              height: 40,
                              color: Colors.blue.shade50,
                              child: Icon(Icons.public, color: Colors.blue.shade700),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '$_selectedBrowserName in use',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                ),
              ),


              const SizedBox(height: 32),

              // Instructions
              Card(
                elevation: 2,
                color: Colors.blue.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 How SafeLink works?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Set this app as your default browser in system settings\n'
                            '2. When you click any link, this app will scan it first\n'
                            '3. Safe links will automatically open in browser set in SafeLink\n'
                            '4. Unsafe links will show notifications',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),

              //MyBannerAdWidget()
            ],
          ),

        ),
      ),
      bottomNavigationBar: MyBannerAdWidget(),
    );
  }
}

class _DefaultBrowserDialog extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _DefaultBrowserDialog({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(24),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surface
                .withValues(alpha: 0.9), // 229
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.2), // 51
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(),
              _Body(onOpenSettings: onOpenSettings),
            ],
          ),
        ),
      ),
    ),
  );
}

// --- Header & body helpers (same layout you already had) -------------
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Center(
      child: Icon(Icons.language_rounded,
          size: 48, color: Theme.of(context).colorScheme.primary),
    ),
  );
}

class _Body extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _Body({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (b) => LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ).createShader(b),
          child: const Text(
            'Make SafeLink Your Default Browser',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'To seamlessly scan URLs from other apps, set SafeLink '
              'as your default browser. This will allow you to:',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),
        _feature(context, 'Open links directly in SafeLink'),
        _feature(context, 'Scan URLs automatically'),
        _feature(context, 'Enhanced security for all browsing'),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: onOpenSettings,
                child: const Text('Open Settings'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _feature(BuildContext c, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(Icons.check_circle_rounded,
            size: 18, color: Theme.of(c).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(c)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.9)))),
      ],
    ),
  );
}
