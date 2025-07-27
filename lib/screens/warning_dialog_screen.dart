// lib/screens/warning_dialog_screen.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/url_handler_service.dart';

class WarningDialogScreen extends StatefulWidget {
  final String url;
  final Map<String, dynamic> apiResult;

  const WarningDialogScreen({
    super.key,
    required this.url,
    required this.apiResult,
  });

  @override
  State<WarningDialogScreen> createState() => _WarningDialogScreenState();
}

class _WarningDialogScreenState extends State<WarningDialogScreen> {
  String? _selectedBrowserIcon;
  String? _predictedLabel;

  @override
  void initState() {
    super.initState();
    _loadBrowserInfo();
    _extractPrediction();
  }

  void _loadBrowserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedPackage = prefs.getString('preferred_browser');
    if (selectedPackage != null) {
      // Load browser icon logic here if needed
    }
  }

  void _extractPrediction() {
    if (widget.apiResult['success']) {
      final data = widget.apiResult['data'];
      _predictedLabel = data['predicted_label']?.toString().toLowerCase();
    }
  }

  // String _formatResult() {
  //   if (!widget.apiResult['success']) {
  //     return '❌ Error: ${widget.apiResult['error']}';
  //   }
  //
  //   final data = widget.apiResult['data'];
  //   final predictedLabel = data['predicted_label'] ?? 'unknown';
  //   // final confidence = data['confidence']?.toDouble();
  //
  //   bool isSafe = predictedLabel.toLowerCase() == 'benign';
  //   String result = isSafe ? '✅ SAFE LINK' : '⚠️ POTENTIALLY UNSAFE LINK';
  //   result += '\nPrediction: ${predictedLabel.toUpperCase()}';
  //
  //   // if (confidence != null) {
  //   //   result += '\nConfidence: ${(confidence * 100).toStringAsFixed(1)}%';
  //   // }
  //
  //   return result;
  // }
  String _formatResult() {
    if (!widget.apiResult['success']) {
      return '❌ Error: ${widget.apiResult['error']}';
    }

    final data = widget.apiResult['data'];
    final predictedLabel = data['predicted_label'] ?? 'unknown';

    bool isSafe = predictedLabel.toLowerCase() == 'benign';
    String result = isSafe ? '✅ SAFE LINK' : '⚠️ POTENTIALLY UNSAFE LINK';
    result += '\nPrediction: ${predictedLabel.toUpperCase()}';

    return result;
  }


  Color get _cardColor {
    if (_predictedLabel == 'benign') {
      return Colors.green.shade50;
    } else {
      return Colors.red.shade50;
    }
  }

  Color get _borderColor {
    if (_predictedLabel == 'benign') {
      return Colors.green.shade200;
    } else {
      return Colors.red.shade200;
    }
  }

  Color get _proceedButtonColor {
    if (_predictedLabel == 'benign') {
      return Colors.green.shade600;
    } else {
      return Colors.red.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _borderColor,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    _buildBody(),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Column(
        children: [
          Icon(
            _predictedLabel == 'benign' ? Icons.security : Icons.warning,
            size: 48,
            color: _predictedLabel == 'benign' ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 12),
          Text(
            'SafeLink',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _predictedLabel == 'benign' ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.url,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatResult(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _predictedLabel == 'benign'
                ? 'This link appears to be safe to visit.'
                : 'This link may be dangerous. Proceed with caution.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await UrlHandlerService.openInBrowser(widget.url);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _proceedButtonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _predictedLabel == 'benign' ? 'Open' : 'Proceed Anyway',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}