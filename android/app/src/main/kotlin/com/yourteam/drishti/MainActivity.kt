package com.yourteam.drishti

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val exec = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var engine: VisionEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "drishti/vision")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> {
                        val thr = call.argument<Number>("threshold")?.toDouble() ?: 0.53
                        exec.execute {
                            val r: Map<String, Any?> = try {
                                engine?.dispose()
                                val e = VisionEngine(applicationContext)
                                engine = e
                                e.init(thr)
                            } catch (t: Throwable) {
                                mapOf("ok" to false, "error" to "${t.javaClass.simpleName}: ${t.message}")
                            }
                            main.post { result.success(r) }
                        }
                    }
                    "process" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val w = call.argument<Number>("width")?.toInt() ?: 0
                        val h = call.argument<Number>("height")?.toInt() ?: 0
                        val stride = call.argument<Number>("stride")?.toInt() ?: w
                        val rot = call.argument<Number>("rotation")?.toInt() ?: 0
                        val t = call.argument<Number>("tMs")?.toLong() ?: 0L
                        exec.execute {
                            val r: Map<String, Any?> = try {
                                val e = engine
                                if (e == null || bytes == null) mapOf("error" to "not_ready")
                                else e.process(bytes, w, h, stride, rot, t)
                            } catch (t2: Throwable) {
                                mapOf("error" to "${t2.javaClass.simpleName}: ${t2.message}")
                            }
                            main.post { result.success(r) }
                        }
                    }
                    "dispose" -> exec.execute {
                        engine?.dispose()
                        engine = null
                        main.post { result.success(null) }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}