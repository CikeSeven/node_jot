package com.nodejot

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "node_jot/network"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireMulticastLock" -> {
                        try {
                            val wifiManager =
                                applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            if (multicastLock == null) {
                                multicastLock = wifiManager.createMulticastLock("node_jot_multicast_lock")
                                multicastLock?.setReferenceCounted(false)
                            }
                            multicastLock?.acquire()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LOCK_ACQUIRE_FAILED", e.message, null)
                        }
                    }

                    "releaseMulticastLock" -> {
                        try {
                            multicastLock?.let {
                                if (it.isHeld) {
                                    it.release()
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LOCK_RELEASE_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}

