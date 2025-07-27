import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const platform = MethodChannel('com.example.safelink/browser');
  static const String ownPackage = 'com.example.safelink';

  String? _selectedBrowser;
  List<Map<String, String>> _browsers = [];
  bool _loading = true;
  bool _noBrowsersFound = false;
  bool _browserChanged = false;

  @override
  void initState() {
    super.initState();
    _loadPreferredBrowser();
    _fetchInstalledBrowsers();
  }

  Future<void> _loadPreferredBrowser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedBrowser = prefs.getString('preferred_browser');
    });
  }

  Future<void> _fetchInstalledBrowsers() async {
    try {
      final List<dynamic> result =
      await platform.invokeMethod('getInstalledBrowsers');

      final List<Map<String, String>> browsers = result
          .map((e) => Map<String, String>.from(e as Map))
          .where((browser) => browser['package'] != ownPackage)
          .toList();

      if (browsers.isEmpty) {
        setState(() {
          _loading = false;
          _noBrowsersFound = true;
        });
      } else {
        if (browsers.length == 1) {
          final singleBrowserPackage = browsers.first['package']!;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('preferred_browser', singleBrowserPackage);
          _selectedBrowser = singleBrowserPackage;
        }

        // setState(() {
        //   _browsers = browsers;
        //   _loading = false;
        // });
        // ... existing code
        setState(() {
          _browsers = browsers;
          _loading = false;
        });

// ✅ Tambah fallback sini
        final prefs = await SharedPreferences.getInstance();
        String? currentPreferred = prefs.getString('preferred_browser');

        if ((currentPreferred == null || currentPreferred.isEmpty) && browsers.length > 1) {
          // Step 1: Cari Chrome
          final chrome = browsers.firstWhere(
                (b) => (b['package'] ?? '').toLowerCase().contains('chrome'),
            orElse: () => {},
          );

          if (chrome.isNotEmpty) {
            currentPreferred = chrome['package'];
          } else {
            // Step 2: fallback ikut abjad nama
            browsers.sort((a, b) =>
                (a['name'] ?? '').toLowerCase().compareTo((b['name'] ?? '').toLowerCase()));
            currentPreferred = browsers.first['package'];
          }

          // Simpan default baru
          await prefs.setString('preferred_browser', currentPreferred!);
          setState(() {
            _selectedBrowser = currentPreferred;
          });
        }


      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get browsers: '${e.message}'.");
      setState(() {
        _loading = false;
        _noBrowsersFound = true;
      });
    }
  }

  Future<void> _savePreferredBrowser(String package) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferred_browser', package);
    setState(() {
      _selectedBrowser = package;
      _browserChanged = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Default browser saved'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // 1️⃣  add this helper inside _SettingsScreenState
  Future<void> _openSystemDefaultAppSettings() async {
    try {
      await platform.invokeMethod('openDefaultAppSettings');
    } on PlatformException catch (e) {
      debugPrint('Failed to open system settings: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open system settings')),
      );
    }
  }

  void _showBrowserSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose a browser',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              itemCount: _browsers.length,
              itemBuilder: (context, index) {
                final browser = _browsers[index];
                final isSelected =
                    browser['package'] == _selectedBrowser;

                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: browser['icon'] != null
                        ? Image.memory(
                      base64Decode(browser['icon']!),
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      width: 36,
                      height: 36,
                      color: Colors.blue.shade50,
                      child: Icon(Icons.public,
                          color: Colors.blue.shade700),
                    ),
                  ),
                  title: Text(browser['name'] ?? 'Unknown Browser'),
                  trailing: Radio<String>(
                    value: browser['package']!,
                    activeColor: Colors.blue,
                    groupValue: _selectedBrowser,
                    onChanged: (val) {
                      _savePreferredBrowser(val!);
                      Navigator.pop(context); // close sheet
                    },
                  ),
                  onTap: () {
                    _savePreferredBrowser(browser['package']!);
                    Navigator.pop(context);
                  },
                  selected: isSelected,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(                             // <‑‑ intercept back
        onWillPop: () async {
          Navigator.pop(context, _browserChanged);     // send result
          return false;                                // cancel default pop
        },
        child: Scaffold(
          // appBar: AppBar(
          //   title: const Text('Browser Preferences'),
          //   centerTitle: true,
          //   elevation: 0,
          //   flexibleSpace: Container(
          //     decoration: BoxDecoration(
          //       gradient: LinearGradient(
          //         colors: [Colors.blue.shade700, Colors.blue.shade500],
          //         begin: Alignment.topLeft,
          //         end: Alignment.bottomRight,
          //       ),
          //     ),
          //   ),
          // ),
          appBar: AppBar(
            title: const Text('Browser Preferences'),
            leading: BackButton(onPressed: () {
              Navigator.pop(context, _browserChanged); // same for toolbar back
            }),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade50,
                  Colors.white,
                ],
              ),
            ),
            child: _loading
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading browsers...',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : _noBrowsersFound
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.blueGrey.shade300,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Browsers Found',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please install a browser like Chrome or Firefox to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _fetchInstalledBrowsers(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
                : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Colors.blue.shade100,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _openSystemDefaultAppSettings,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.settings_applications,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Set SafeLink as default browser',
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Required if you want SafeLink to scan links seamlessly from other apps.',
                                    style: TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select Browser',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose which browser to use for SafeLink to open links',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showBrowserSelector,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: (_browsers
                                  .firstWhere(
                                    (b) => b['package'] == _selectedBrowser,
                                orElse: () => {},
                              )['icon']) !=
                                  null
                                  ? Image.memory(
                                base64Decode(_browsers
                                    .firstWhere(
                                      (b) => b['package'] == _selectedBrowser,
                                  orElse: () => {},
                                )['icon']!),
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
                                _browsers
                                    .firstWhere(
                                      (b) => b['package'] == _selectedBrowser,
                                  orElse: () => {'name': 'Select browser'},
                                )['name'] ??
                                    'Select browser',
                                style:
                                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}