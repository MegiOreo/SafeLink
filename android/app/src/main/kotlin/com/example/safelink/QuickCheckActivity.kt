//////class QuickCheckActivity : Activity() {
//////    override fun onCreate(savedInstanceState: Bundle?) {
//////        super.onCreate(savedInstanceState)
//////        val url = intent?.dataString
//////        if (url != null) {
//////            val work = OneTimeWorkRequestBuilder<LinkScanWorker>()
//////                .setInputData(workDataOf("url" to url))
//////                .build()
//////            WorkManager.getInstance(this).enqueue(work)
//////        }
//////        finish()           // tutup sebelum frame pertama–tiada UI.
//////    }
//////}
////
////package com.example.safelink
////
////import android.app.Activity
////import android.content.Intent
////import android.os.Bundle
////import android.util.Log
////import io.flutter.embedding.engine.FlutterEngine
////import io.flutter.embedding.engine.dart.DartExecutor
////import io.flutter.embedding.engine.FlutterEngineCache
////import io.flutter.plugin.common.MethodChannel
////
////class QuickCheckActivity : Activity() {
////    private val CHANNEL = "com.example.safelink/browser"
////
////    override fun onCreate(savedInstanceState: Bundle?) {
////        super.onCreate(savedInstanceState)
////
////        val url = intent?.data?.toString()
////        if (url == null) {
////            finish()
////            return
////        }
////
////        Log.d("QuickCheck", "Received URL: $url")
////
////        // Init Flutter Engine
////        val flutterEngine = FlutterEngine(this)
////        flutterEngine.dartExecutor.executeDartEntrypoint(
////            DartExecutor.DartEntrypoint.createDefault()
////        )
////
////        // Optional: Cache if needed
////        FlutterEngineCache.getInstance().put("bg_engine", flutterEngine)
////
////        // Call Dart method from background (if needed), or do it in this Activity
////        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
////            .invokeMethod("handleQuickCheck", url)
////
////        // Close activity (headless)
////        finish()
////    }
////}
////
//
//package com.example.safelink
//
//import android.app.Activity
//import android.content.Intent
//import android.net.Uri
//import android.os.Bundle
//import android.util.Log
//import io.flutter.embedding.engine.FlutterEngine
//import io.flutter.embedding.engine.FlutterEngineCache
//import io.flutter.embedding.engine.dart.DartExecutor
//import io.flutter.plugin.common.MethodChannel
//
//class QuickCheckActivity : Activity() {
//    private val CHANNEL = "com.example.safelink/browser"
//
//    override fun onCreate(savedInstanceState: Bundle?) {
//        super.onCreate(savedInstanceState)
//
//        val url = intent?.data?.toString()
//        if (url == null) {
//            finish()
//            return
//        }
//
//        Log.d("QuickCheck", "Received URL: $url")
//
//        // Init new FlutterEngine for background
//        val flutterEngine = FlutterEngine(this)
//        flutterEngine.dartExecutor.executeDartEntrypoint(
//            DartExecutor.DartEntrypoint.createDefault()
//        )
//        FlutterEngineCache.getInstance().put("bg_engine", flutterEngine)
//
//        // Register MethodChannel manually
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
//            .setMethodCallHandler { call, result ->
//                when (call.method) {
//                    "openInBrowser" -> {
//                        val pkg = call.argument<String>("package")
//                        val targetUrl = call.argument<String>("url")
//                        if (pkg != null && targetUrl != null) {
//                            try {
//                                val intent = Intent(Intent.ACTION_VIEW)
//                                intent.setPackage(pkg)
//                                intent.data = Uri.parse(targetUrl)
//                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
//                                startActivity(intent)
//                                result.success(true)
//                            } catch (e: Exception) {
//                                result.error("ERROR", "Browser not found", null)
//                            }
//                        } else {
//                            result.error("INVALID_ARGUMENTS", "Missing data", null)
//                        }
//                    }
//
//                    else -> result.notImplemented()
//                }
//            }
//
//        // Fire Dart method
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
//            .invokeMethod("handleQuickCheck", url)
//
//        // Exit this headless activity
//        finish()
//    }
//}
//

package com.example.safelink

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class QuickCheckActivity : Activity() {
    private val CHANNEL = "com.example.safelink/browser"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val url = intent?.data?.toString()
        if (url == null) {
            finish()
            return
        }

        Log.d("QuickCheck", "Received URL: $url")

        // 1. Init Flutter engine
        val flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        // 2. MethodChannel untuk handle result dari Dart
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "done" -> {
                    Log.d("QuickCheck", "✅ Dart done, closing activity")
                    result.success(null)
                    finish()
                }

                "openInBrowser" -> {
                    val pkg = call.argument<String>("package")
                    val targetUrl = call.argument<String>("url")
                    if (pkg != null && targetUrl != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW)
                            intent.setPackage(pkg)
                            intent.data = Uri.parse(targetUrl)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", "Browser not found", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing data", null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // 3. Trigger Dart to start processing
        channel.invokeMethod("handleQuickCheck", url)
    }
}

