package app.syberia.client

import android.content.Context
import org.json.JSONObject

/** What one widget on the home screen looks like and shows, set in the app. */
data class WidgetConfig(
    val theme: String = "brand",
    val showRoom: Boolean = true,
    val showTeacher: Boolean = false,
    val showNextLessons: Boolean = true,
    val showCountdown: Boolean = true,
    val showProgress: Boolean = true,
    val highlightSubstitutions: Boolean = true,
    val mergeDoubleLessons: Boolean = true,
) {
    companion object {
        const val PREFERENCES = "siberia_home_widget"

        private fun key(id: Int) = "config_$id"

        /** The stored settings as the app wrote them, or null for the defaults. */
        fun raw(context: Context, id: Int): String? =
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getString(key(id), null)

        fun load(context: Context, id: Int): WidgetConfig = parse(raw(context, id))

        fun save(context: Context, id: Int, raw: String) {
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .edit().putString(key(id), raw).apply()
        }

        fun delete(context: Context, ids: IntArray) {
            val editor = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
            ids.forEach { editor.remove(key(it)) }
            editor.apply()
        }

        private fun parse(raw: String?): WidgetConfig {
            val defaults = WidgetConfig()
            if (raw == null) return defaults
            return try {
                val json = JSONObject(raw)
                WidgetConfig(
                    theme = json.optString("theme", defaults.theme),
                    showRoom = json.optBoolean("showRoom", defaults.showRoom),
                    showTeacher = json.optBoolean("showTeacher", defaults.showTeacher),
                    showNextLessons = json.optBoolean("showNextLessons", defaults.showNextLessons),
                    showCountdown = json.optBoolean("showCountdown", defaults.showCountdown),
                    showProgress = json.optBoolean("showProgress", defaults.showProgress),
                    highlightSubstitutions =
                        json.optBoolean("highlightSubstitutions", defaults.highlightSubstitutions),
                    mergeDoubleLessons = json.optBoolean("mergeDoubleLessons", defaults.mergeDoubleLessons),
                )
            } catch (error: Exception) {
                defaults
            }
        }
    }
}
