package app.syberia.client

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Connects the Flutter app to the home screen widget: its lessons and settings. */
object HomeWidgetChannel {
    /**
     * [configuring] is the widget a launcher opened [WidgetConfigActivity] to
     * set up, and [onConfigured] closes that screen.
     */
    fun register(
        context: Context,
        messenger: BinaryMessenger,
        configuring: Int? = null,
        onConfigured: (() -> Unit)? = null,
    ) {
        val app = context.applicationContext
        MethodChannel(messenger, "siberia/home_widget").setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val payload = call.argument<String>("payload")
                    // Each profile's lessons, for widgets set to show it.
                    val profiles = call.argument<Map<String, String>>("profiles").orEmpty()
                    if (payload == null) {
                        result.error("invalid_arguments", null, null)
                    } else {
                        NextLessonWidgetProvider.savePayload(app, payload, profiles)
                        result.success(null)
                    }
                }
                "clear" -> {
                    NextLessonWidgetProvider.savePayload(app, null)
                    result.success(null)
                }
                "placedWidgets" -> result.success(NextLessonWidgetProvider.placedWidgets(app))
                "loadConfig" -> {
                    val id = call.argument<Int>("id")
                    result.success(id?.let { WidgetConfig.raw(app, it) })
                }
                "saveConfig" -> {
                    val id = call.argument<Int>("id")
                    val config = call.argument<String>("config")
                    if (id == null || config == null) {
                        result.error("invalid_arguments", null, null)
                    } else {
                        WidgetConfig.save(app, id, config)
                        NextLessonWidgetProvider.refresh(app, id)
                        result.success(null)
                    }
                }
                "dynamicColorsSupported" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                // The launcher places the widget with its own dialog.
                "canPinWidget" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        AppWidgetManager.getInstance(app).isRequestPinAppWidgetSupported,
                )
                "pinWidget" -> result.success(
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        AppWidgetManager.getInstance(app).requestPinAppWidget(
                            ComponentName(app, NextLessonWidgetProvider::class.java),
                            null,
                            null,
                        ),
                )
                "configuringWidgetId" -> result.success(configuring)
                "finishConfiguring" -> {
                    result.success(null)
                    onConfigured?.invoke()
                }
                else -> result.notImplemented()
            }
        }
    }
}
