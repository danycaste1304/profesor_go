package edu.profesorgo.profesor_go

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Dart side: lib/features/capture/presentation/nfc_settings_opener.dart
            "openNfcSettings" -> result.success(openNfcSettings())
            else -> result.notImplemented()
        }
    }

    /**
     * Opens the system NFC settings. Returns false (never throws) when no
     * activity can handle the intent, so the UI can explain it to the user.
     */
    private fun openNfcSettings(): Boolean =
        try {
            startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
            true
        } catch (e: ActivityNotFoundException) {
            false
        }

    private companion object {
        const val CHANNEL = "edu.profesorgo/settings"
    }
}
