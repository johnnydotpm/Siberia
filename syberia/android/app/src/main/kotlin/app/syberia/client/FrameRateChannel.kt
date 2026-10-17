package app.syberia.client

import android.app.Activity
import android.os.Build
import android.view.Display
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Lets the app move at the screen's top refresh rate and hands the rate back
 * to the system once it is still.
 *
 * Some systems keep apps at 60 Hz unless they ask for more. Dart sends
 * "boost" while frames come in quick succession (scrolling, animations) and
 * "release" a moment after the last one. Released, the app states no
 * preference, so an LTPO screen can go down to its minimum, as low as 1 Hz.
 */
class FrameRateChannel private constructor(private val activity: Activity) {
    private var boosted = false

    private fun boost() {
        val window = activity.window ?: return
        val display = display() ?: return
        val current = display.mode
        // Only rates at the current resolution, so the picture never resizes.
        val fastest = display.supportedModes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .maxByOrNull { it.refreshRate } ?: return
        if (fastest.refreshRate <= 61f) return
        boosted = true
        val attributes = window.attributes
        if (attributes.preferredDisplayModeId != fastest.modeId) {
            attributes.preferredDisplayModeId = fastest.modeId
            window.attributes = attributes
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // On Android 12 and newer this only changes the rate where the
            // switch is seamless, so the screen never blanks.
            flutterSurface()?.setFrameRate(
                fastest.refreshRate,
                Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
            )
        }
    }

    /** Gives the choice back to the system; also called when the app leaves. */
    fun release() {
        if (!boosted) return
        boosted = false
        try {
            val window = activity.window ?: return
            val attributes = window.attributes
            if (attributes.preferredDisplayModeId != 0) {
                attributes.preferredDisplayModeId = 0
                window.attributes = attributes
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                flutterSurface()?.setFrameRate(0f, Surface.FRAME_RATE_COMPATIBILITY_DEFAULT)
            }
        } catch (error: RuntimeException) {
            // A device without these controls keeps its own behaviour.
        }
    }

    @Suppress("DEPRECATION")
    private fun display(): Display? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display
        } else {
            activity.windowManager.defaultDisplay
        }

    /** The surface Flutter draws on, when it draws on a SurfaceView. */
    private fun flutterSurface(): Surface? {
        val root = activity.findViewById<View>(FlutterActivity.FLUTTER_VIEW_ID) ?: return null
        val view = findSurfaceView(root) ?: return null
        return view.holder.surface?.takeIf { it.isValid }
    }

    private fun findSurfaceView(view: View): SurfaceView? {
        if (view is SurfaceView) return view
        if (view !is ViewGroup) return null
        for (index in 0 until view.childCount) {
            findSurfaceView(view.getChildAt(index))?.let { return it }
        }
        return null
    }

    companion object {
        fun register(activity: Activity, messenger: BinaryMessenger): FrameRateChannel {
            val channel = FrameRateChannel(activity)
            MethodChannel(messenger, "app.syberia.client/frame_rate").setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "boost" -> channel.boost()
                        "release" -> channel.release()
                        else -> {
                            result.notImplemented()
                            return@setMethodCallHandler
                        }
                    }
                } catch (error: RuntimeException) {
                    // An unusual display only loses the higher rate.
                }
                result.success(null)
            }
            return channel
        }
    }
}
