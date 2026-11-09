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
    /** The profile whose lessons it shows; null for the one chosen in the app. */
    val profileId: String? = null,
) {
    companion object {
        const val PREFERENCES = "siberia_home_widget"

        private fun key(id: Int) = "config_$id"
        private const val DEFAULT_THEME_KEY = "default_theme"

        /** The stored settings as the app wrote them, or null for the defaults. */
        fun raw(context: Context, id: Int): String? =
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getString(key(id), null)

        /**
         * The settings for the app's own screen: the stored ones, or the
         * defaults with the theme a widget gets before it is set up.
         */
        fun rawOrDefaults(context: Context, id: Int): String =
            raw(context, id) ?: JSONObject().put("theme", defaultTheme(context)).toString()

        fun load(context: Context, id: Int): WidgetConfig = parse(raw(context, id), defaultTheme(context))

        /**
         * The theme of a widget nobody has set up: the wallpaper's colours
         * while the app itself takes them, the brand colour otherwise.
         */
        fun defaultTheme(context: Context): String =
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .getString(DEFAULT_THEME_KEY, null) ?: WidgetConfig().theme

        fun saveDefaultTheme(context: Context, theme: String) {
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .edit().putString(DEFAULT_THEME_KEY, theme).apply()
        }

        /** The widgets that follow the default theme: those not set up. */
        fun usesDefaults(context: Context, id: Int): Boolean = raw(context, id) == null

        fun save(context: Context, id: Int, raw: String) {
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .edit().putString(key(id), raw).apply()
        }

        fun delete(context: Context, ids: IntArray) {
            val editor = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
            ids.forEach { editor.remove(key(it)) }
            editor.apply()
        }

        private fun parse(raw: String?, defaultTheme: String): WidgetConfig {
            val defaults = WidgetConfig(theme = defaultTheme)
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
                    profileId = json.optString("profileId").takeIf { it.isNotEmpty() },
                )
            } catch (error: Exception) {
                defaults
            }
        }
    }
}
