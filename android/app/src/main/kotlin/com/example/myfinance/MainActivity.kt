package com.example.myfinance

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "com.example.myfinance/gpay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences("myfinance_prefs", Context.MODE_PRIVATE)
                when (call.method) {

                    "checkGPayClosed" -> {
                        val closed = prefs.getBoolean("gpay_just_closed", false)
                        if (closed) prefs.edit().putBoolean("gpay_just_closed", false).apply()
                        result.success(closed)
                    }

                    "getPendingAction" -> {
                        val action = prefs.getString("pending_action", null)
                        if (action != null) prefs.edit().remove("pending_action").apply()
                        result.success(action)
                    }

                    "getPendingPersonalExpenses" -> {
                        val raw = prefs.getString("pending_personal_expenses", "") ?: ""
                        if (raw.isNotEmpty()) {
                            prefs.edit().remove("pending_personal_expenses").apply()
                        }
                        // Return list of amounts as comma-separated string
                        result.success(raw)
                    }

                    "openAccessibilitySettings" -> {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(null)
                    }

                    "isAccessibilityEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }

                    "isAppInstalled" -> {
                        val pkg = call.arguments as? String ?: ""
                        try {
                            packageManager.getPackageInfo(pkg, 0)
                            result.success(true)
                        } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
                            result.success(false)
                        }
                    }

                    "openApp" -> {
                        val pkg = call.arguments as? String ?: ""
                        val intent = packageManager.getLaunchIntentForPackage(pkg)
                        if (intent != null) {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(null)
                        } else {
                            result.error("NOT_INSTALLED", "App not installed", null)
                        }
                    }

                    "launchUpiPayment" -> {
                        val upi = call.argument<String>("upi") ?: ""
                        val pkg = call.argument<String>("package") ?: ""
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(upi)).apply {
                                setPackage(pkg)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("LAUNCH_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val serviceName = "$packageName/${GPayWatcherService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.split(":").any { it.equals(serviceName, ignoreCase = true) }
    }
}
