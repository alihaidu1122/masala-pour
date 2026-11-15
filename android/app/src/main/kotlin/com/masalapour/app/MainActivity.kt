package com.masalapour.app

import android.annotation.SuppressLint
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "masala/device_id")
            .setMethodCallHandler { call, result ->
                if (call.method == "getStableId") {
                    // ANDROID_ID is unique per app-signing key + device user and
                    // stays the same across uninstall/reinstall (changes only on
                    // factory reset). Used only to restore this phone's backup.
                    @SuppressLint("HardwareIds")
                    val id = Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ANDROID_ID,
                    )
                    result.success(id)
                } else {
                    result.notImplemented()
                }
            }
    }
}
