package com.example.accountingsystem

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // مسار ملف الـ APK نفسه — يقرأه التطبيق لاستخراج معرّف الفرع
        // المضمّن في ذيله (@@ZSYS=...@@) دون أي ملفات خارجية.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/embedded")
            .setMethodCallHandler { call, result ->
                if (call.method == "apkPath") {
                    result.success(applicationInfo.sourceDir)
                } else {
                    result.notImplemented()
                }
            }
    }
}
