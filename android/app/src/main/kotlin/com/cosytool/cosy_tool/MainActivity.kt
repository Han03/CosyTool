package com.cosytool.cosy_tool

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.cosytool.cosy_tool/audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBluetoothAudioOn" -> {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    result.success(am.isBluetoothA2dpOn || am.isBluetoothScoOn)
                }
                else -> result.notImplemented()
            }
        }
    }
}
