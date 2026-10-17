package app.syberia.client

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * The settings of one home screen widget, opened by the launcher when the
 * widget is placed or edited. Flutter draws it (`widgetConfigMain` in
 * main.dart), so it looks like the rest of the app and speaks its language.
 */
class WidgetConfigActivity : FlutterActivity() {
    private val widgetId: Int
        get() = intent?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The defaults suit most students, so leaving without saving keeps
        // the widget rather than taking it off the home screen.
        setResult(RESULT_OK, result())
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) finish()
    }

    override fun getDartEntrypointFunctionName(): String = "widgetConfigMain"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val id = widgetId
        HomeWidgetChannel.register(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
            configuring = id.takeIf { it != AppWidgetManager.INVALID_APPWIDGET_ID },
        ) {
            NextLessonWidgetProvider.refresh(applicationContext, id)
            setResult(RESULT_OK, result())
            finish()
        }
    }

    private fun result() = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
}
