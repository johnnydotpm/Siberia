package app.syberia.client

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var frameRate: FrameRateChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        HomeWidgetChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)
        frameRate = FrameRateChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)
        VpnChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onPause() {
        // A higher rate is only for the app on screen.
        frameRate?.release()
        super.onPause()
    }
}
