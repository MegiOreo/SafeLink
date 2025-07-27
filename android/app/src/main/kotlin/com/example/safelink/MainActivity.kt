////package com.example.safelink
////
////import io.flutter.embedding.android.FlutterActivity
////
////class MainActivity: FlutterActivity()
////
////
//////package com.example.safelink
//////
//////import android.content.Intent
//////import android.os.Bundle
//////import io.flutter.embedding.android.FlutterActivity
//////import io.flutter.embedding.engine.FlutterEngine
//////import io.flutter.plugin.common.MethodChannel
//////
//////class MainActivity: FlutterActivity() {
//////    override fun onCreate(savedInstanceState: Bundle?) {
//////        super.onCreate(savedInstanceState)
//////        handleIntent(intent)
//////    }
//////
//////    override fun onNewIntent(intent: Intent) {
//////        super.onNewIntent(intent)
//////        handleIntent(intent)
//////    }
//////
//////    private fun handleIntent(intent: Intent) {
//////        val url = intent.dataString ?: return
//////        MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger, "com.example.safelink/intent")
//////            .invokeMethod("handleUrl", mapOf("url" to url))
//////    }
//////}
//
//// android/app/src/main/kotlin/com/example/safelink/MainActivity.kt
//
//package com.example.safelink
//
//import android.content.Intent
//import android.content.pm.PackageManager
//import android.os.Bundle
//import io.flutter.embedding.android.FlutterActivity
//import io.flutter.embedding.engine.FlutterEngine
//import io.flutter.plugin.common.MethodChannel
//
//class MainActivity: FlutterActivity() {
//    private val CHANNEL = "com.example.safelink/browser"
//
//    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
//        super.configureFlutterEngine(flutterEngine)
//
//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
//                call, result ->
//            if (call.method == "getInstalledBrowsers") {
//                val browsers = getInstalledBrowsers()
//                result.success(browsers)
//            } else {
//                result.notImplemented()
//            }
//        }
//    }
//
//    private fun getInstalledBrowsers(): List<Map<String, String>> {
//        val pm = packageManager
//        val intent = Intent(Intent.ACTION_VIEW)
//        intent.data = android.net.Uri.parse("http://")
//        val resolveInfos = pm.queryIntentActivities(intent, 0)
//
//        return resolveInfos.map {
//            mapOf(
//                "name" to it.loadLabel(pm).toString(),
//                "package" to it.activityInfo.packageName
//            )
//        }
//    }
//}

package com.example.safelink

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.Base64
import java.io.ByteArrayOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
// ADD these imports if not present
import android.content.pm.PackageManager
import android.os.Build
import android.app.role.RoleManager


class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.safelink/browser"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

//        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
////            .setMethodCallHandler { call, result ->
////                if (call.method == "getInstalledBrowsers") {
////                    val browsers = getInstalledBrowsers()
////                    result.success(browsers)
////                } else {
////                    result.notImplemented()
////                }
////            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledBrowsers" -> {
                        val browsers = getInstalledBrowsers()
                        result.success(browsers)
                    }

                    "openInBrowser" -> {
                        val url = call.argument<String>("url")
                        val packageName = call.argument<String>("package")

                        if (url != null && packageName != null) {
                            try {
                                val intent = Intent(Intent.ACTION_VIEW)
                                intent.data = Uri.parse(url)
                                intent.setPackage(packageName)
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("ERROR", "Failed to open browser: ${e.message}", null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "Missing URL or package name", null)
                        }
                    }

                    "openDefaultAppSettings" -> {
                        try {
                            val intent = Intent("android.settings.MANAGE_DEFAULT_APPS_SETTINGS")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to open default app settings: ${e.message}", null)
                        }
                    }

                    // INSIDE the existing when(call.method) { … } block
                    "isDefaultBrowser" -> {
                        try {
                            val isDefault = isAppDefaultBrowser()
                            result.success(isDefault)
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to check default browser: ${e.message}", null)
                        }
                    }




                    else -> result.notImplemented()
                }
            }

    }

    // ADD this helper function anywhere in MainActivity
    private fun isAppDefaultBrowser(): Boolean {
        val pm = packageManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            roleManager?.isRoleHeld(RoleManager.ROLE_BROWSER) == true
        } else {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("http://"))
            val defaultApp = intent.resolveActivity(pm)?.packageName
            defaultApp == packageName
        }
    }


//    private fun getInstalledBrowsers(): List<Map<String, String>> {
//        val browsers = mutableListOf<Map<String, String>>()
//        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("http://"))
//        val pm = packageManager
//        val resolveInfoList = pm.queryIntentActivities(intent, 0)
//
//        for (info in resolveInfoList) {
//            val packageName = info.activityInfo.packageName
//            val appName = info.loadLabel(pm).toString()
//            val iconDrawable = info.loadIcon(pm)
//            val bitmap = drawableToBitmap(iconDrawable)
//
//            val stream = ByteArrayOutputStream()
//            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
//            val iconBytes = stream.toByteArray()
//            val iconBase64 = Base64.encodeToString(iconBytes, Base64.NO_WRAP)
//
//            browsers.add(
//                mapOf(
//                    "name" to appName,
//                    "package" to packageName,
//                    "icon" to iconBase64
//                )
//            )
//        }
//
//        return browsers
//    }

    private fun getInstalledBrowsers(): List<Map<String, String>> {
        val browsers = mutableListOf<Map<String, String>>()

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("http://"))
            .addCategory(Intent.CATEGORY_BROWSABLE)

        val pm = packageManager

        @Suppress("DEPRECATION")
        val resolveInfoList = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // New typed‑flags API (API 33+)
            pm.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_ALL.toLong())
            )
        } else {
            // Legacy int‑flags API
            pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)
        }

        for (info in resolveInfoList) {
            val appName = info.loadLabel(pm).toString()
            val packageName = info.activityInfo.packageName
            val iconDrawable = info.loadIcon(pm)

            // encode icon → base64
            val bitmap = drawableToBitmap(iconDrawable)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            val iconBase64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)

            browsers += mapOf(
                "name" to appName,
                "package" to packageName,
                "icon" to iconBase64
            )
        }

        return browsers
    }



    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) {
            return drawable.bitmap
        }
        val bitmap = Bitmap.createBitmap(
            drawable.intrinsicWidth.takeIf { it > 0 } ?: 48,
            drawable.intrinsicHeight.takeIf { it > 0 } ?: 48,
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}

/*
package com.example.safelink

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.graphics.*
import android.graphics.drawable.*
import android.util.Base64
import android.content.pm.PackageManager
import android.app.role.RoleManager
import java.io.ByteArrayOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall


class MainActivity : FlutterActivity() {

    /*  ─────────────────────────────
        Constants
    ──────────────────────────────── */
    private val BROWSER_CHANNEL = "com.example.safelink/browser"
    private val INTENT_CHANNEL  = "com.example.safelink/intent"

    /*  ─────────────────────────────
        Flutter engine wiring
    ──────────────────────────────── */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        /* 1️⃣  Browser utilities channel  */
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BROWSER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledBrowsers" -> result.success(getInstalledBrowsers())
                    "openInBrowser"        -> handleOpenInBrowser(call, result)
                    "openDefaultAppSettings" -> handleOpenSettings(result)
                    "isDefaultBrowser"       -> result.success(isAppDefaultBrowser())
                    else -> result.notImplemented()
                }
            }

        /* 2️⃣  Intent bridge channel  */
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInitialUrl") {
                    // May be null on normal cold‑start
                    result.success(intent.getStringExtra("url"))
                } else {
                    result.notImplemented()
                }
            }
    }

    /*  ─────────────────────────────
        Handle new intents while app alive
    ──────────────────────────────── */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)                               // update internal reference

        val url = intent.getStringExtra("url") ?: return
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, INTENT_CHANNEL)
                .invokeMethod("incomingUrl", url)
        }
    }

    /*  ─────────────────────────────
        Helpers: browser list, open link, etc.
    ──────────────────────────────── */
    private fun getInstalledBrowsers(): List<Map<String, String>> {
        val browsers = mutableListOf<Map<String, String>>()
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("http://"))
            .addCategory(Intent.CATEGORY_BROWSABLE)
        val pm = packageManager

        @Suppress("DEPRECATION")
        val resolveInfoList = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_ALL.toLong())
            )
        } else {
            pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)
        }

        for (info in resolveInfoList) {
            val iconDrawable = info.loadIcon(pm)
            val bitmap = drawableToBitmap(iconDrawable)
            val baos = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, baos)
            browsers += mapOf(
                "name"    to info.loadLabel(pm).toString(),
                "package" to info.activityInfo.packageName,
                "icon"    to Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
            )
        }
        return browsers
    }

    //private fun handleOpenInBrowser(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
    private fun handleOpenInBrowser(call: MethodCall, result: MethodChannel.Result) {
        val url   = call.argument<String>("url")
        val pkg   = call.argument<String>("package")
        if (url == null || pkg == null) {
            result.error("INVALID_ARGS", "Missing URL or package name", null); return
        }
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                setPackage(pkg)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Failed to open browser: ${e.message}", null)
        }
    }

    private fun handleOpenSettings(result: MethodChannel.Result) {
        try {
            startActivity(Intent("android.settings.MANAGE_DEFAULT_APPS_SETTINGS")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Failed to open default app settings: ${e.message}", null)
        }
    }

    private fun isAppDefaultBrowser(): Boolean {
        val pm = packageManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            getSystemService(RoleManager::class.java)
                ?.isRoleHeld(RoleManager.ROLE_BROWSER) == true
        } else {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("http://"))
            intent.resolveActivity(pm)?.packageName == packageName
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) return drawable.bitmap
        val bmp = Bitmap.createBitmap(
            drawable.intrinsicWidth.takeIf { it > 0 } ?: 48,
            drawable.intrinsicHeight.takeIf { it > 0 } ?: 48,
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bmp)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bmp
    }
}



* */