package app.syberia.client

import android.annotation.TargetApi
import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.text.format.DateFormat
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Date
import java.util.Locale
import kotlin.math.floor
import kotlin.math.min

/**
 * Home screen widget with the current or next lesson.
 *
 * The app stores today's and the next two weeks' lessons; the widget picks
 * "now" and "next" from the clock and asks to be redrawn when a lesson starts
 * or ends, so it stays right without the app running. Its layout follows its
 * size (a one-line strip, a square, or a wide card with the following
 * lessons) and its look and content follow the settings of each widget.
 */
class NextLessonWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { render(context, manager, it, payloadFor(context, it)) }
        scheduleNextRefresh(context, allPayloads(context))
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: Bundle,
    ) {
        render(context, manager, id, payloadFor(context, id))
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        WidgetConfig.delete(context, ids)
    }

    override fun onDisabled(context: Context) {
        alarmManager(context).cancel(refreshIntent(context))
    }

    companion object {
        /** The lessons of the profile chosen for widgets in the app. */
        private const val PAYLOAD_KEY = "next_lessons_v1"

        /** Each profile's lessons, for the widgets set to show it. */
        private const val PROFILE_PREFIX = "${PAYLOAD_KEY}_"

        private fun profileKey(profileId: String) = PROFILE_PREFIX + profileId

        /**
         * Saves the lessons the app sent: [payload] for widgets without a
         * profile of their own, [profiles] by profile id. Profiles the app no
         * longer sends are forgotten.
         */
        fun savePayload(context: Context, payload: String?, profiles: Map<String, String> = emptyMap()) {
            val preferences = context.getSharedPreferences(WidgetConfig.PREFERENCES, Context.MODE_PRIVATE)
            preferences.edit().apply {
                if (payload == null) remove(PAYLOAD_KEY) else putString(PAYLOAD_KEY, payload)
                preferences.all.keys
                    .filter { it.startsWith(PROFILE_PREFIX) && it.removePrefix(PROFILE_PREFIX) !in profiles }
                    .forEach { remove(it) }
                profiles.forEach { (id, raw) -> putString(profileKey(id), raw) }
            }.apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = widgetIds(context)
            if (ids.isEmpty()) return
            ids.forEach { render(context, manager, it, payloadFor(context, it)) }
            scheduleNextRefresh(context, allPayloads(context))
        }

        /** Redraws one widget, after its settings changed. */
        fun refresh(context: Context, id: Int) {
            render(context, AppWidgetManager.getInstance(context), id, payloadFor(context, id))
        }

        /**
         * The lessons widget [id] shows: its profile's, or the common ones
         * when it has none or the profile is gone.
         */
        private fun payloadFor(context: Context, id: Int): WidgetPayload? {
            val profile = WidgetConfig.load(context, id).profileId
            return profile?.let { loadPayload(context, profileKey(it)) } ?: loadPayload(context, PAYLOAD_KEY)
        }

        /** Every saved set of lessons, for the next time a widget must change. */
        private fun allPayloads(context: Context): List<WidgetPayload> {
            val keys = context.getSharedPreferences(WidgetConfig.PREFERENCES, Context.MODE_PRIVATE)
                .all.keys.filter { it == PAYLOAD_KEY || it.startsWith(PROFILE_PREFIX) }
            return keys.mapNotNull { loadPayload(context, it) }
        }

        /** The widgets on the home screen with their sizes in dp, for the app's settings. */
        fun placedWidgets(context: Context): List<Map<String, Int>> {
            val manager = AppWidgetManager.getInstance(context)
            return widgetIds(context).map { id ->
                val options = manager.getAppWidgetOptions(id)
                mapOf(
                    "id" to id,
                    "width" to options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH),
                    "height" to options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT),
                )
            }
        }

        private fun widgetIds(context: Context): IntArray =
            AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, NextLessonWidgetProvider::class.java))

        private fun loadPayload(context: Context, key: String): WidgetPayload? {
            val raw = context.getSharedPreferences(WidgetConfig.PREFERENCES, Context.MODE_PRIVATE)
                .getString(key, null) ?: return null
            return try {
                val json = JSONObject(raw)
                val labels = json.getJSONObject("labels")
                val items = json.getJSONArray("lessons")
                val language = json.optString("locale")
                WidgetPayload(
                    locale = if (language.isEmpty()) Locale.getDefault() else Locale.forLanguageTag(language),
                    labels = WidgetLabels(
                        now = labels.optString("now"),
                        next = labels.optString("next"),
                        onBreak = labels.optString("break"),
                        tomorrow = labels.optString("tomorrow"),
                        substitution = labels.optString("substitution"),
                        startsIn = labels.optString("startsIn"),
                        endsIn = labels.optString("endsIn"),
                        lessonsFew = labels.optString("lessonsFew"),
                        lessonsMany = labels.optString("lessonsMany"),
                        noLessons = labels.optString("noLessons"),
                    ),
                    lessons = (0 until items.length()).map { index ->
                        val item = items.getJSONObject(index)
                        WidgetLesson(
                            subject = item.optString("subject"),
                            room = item.optString("room"),
                            teacher = item.optString("teacher"),
                            start = item.getLong("start"),
                            end = item.getLong("end"),
                            substitution = item.optBoolean("substitution"),
                        )
                    }.sortedBy { it.start },
                )
            } catch (error: Exception) {
                null
            }
        }

        private fun render(context: Context, manager: AppWidgetManager, id: Int, payload: WidgetPayload?) {
            val layouts = LessonLayouts(context, payload, WidgetConfig.load(context, id), System.currentTimeMillis())
            val options = manager.getAppWidgetOptions(id)
            val sizes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) widgetSizes(options) else emptyList()
            val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && sizes.isNotEmpty()) {
                // The launcher picks the layout made for its exact size, in
                // portrait and in landscape.
                RemoteViews(sizes.take(16).associateWith { layouts.build(it.width, it.height) })
            } else {
                // Before Android 12 the portrait size is the minimum width and
                // the maximum height.
                val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
                val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
                layouts.build(
                    if (width > 0) width.toFloat() else 170f,
                    if (height > 0) height.toFloat() else 170f,
                )
            }
            manager.updateAppWidget(id, views)
        }

        @TargetApi(Build.VERSION_CODES.S)
        private fun widgetSizes(options: Bundle): List<SizeF> {
            val sizes: List<SizeF>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                options.getParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES, SizeF::class.java)
            } else {
                @Suppress("DEPRECATION")
                options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            }
            return sizes.orEmpty()
        }

        /**
         * Redraws the widget when a lesson starts or ends, and when a lesson
         * comes close enough for its countdown.
         */
        private fun scheduleNextRefresh(context: Context, payloads: List<WidgetPayload>) {
            val now = System.currentTimeMillis()
            val next = payloads
                .flatMap { it.lessons }
                .flatMap { listOf(it.start - COUNTDOWN_WINDOW, it.start, it.end) }
                .filter { it > now }
                .minOrNull()
            val alarms = alarmManager(context)
            val intent = refreshIntent(context)
            if (next == null) {
                alarms.cancel(intent)
            } else {
                // A short window needs no special permission and keeps the
                // countdown from running past zero for long.
                alarms.setWindow(AlarmManager.RTC, next + 1_000, 30_000, intent)
            }
        }

        private fun alarmManager(context: Context) =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        private fun refreshIntent(context: Context): PendingIntent {
            val intent = Intent(context, NextLessonWidgetProvider::class.java)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds(context))
            return PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
    }
}

/** How long before a lesson its countdown appears. */
private const val COUNTDOWN_WINDOW = 2 * 60 * 60 * 1000L

private data class WidgetLesson(
    val subject: String,
    val room: String,
    val teacher: String,
    val start: Long,
    val end: Long,
    val substitution: Boolean,
)

private data class WidgetLabels(
    val now: String,
    val next: String,
    val onBreak: String,
    val tomorrow: String,
    val substitution: String,
    val startsIn: String,
    val endsIn: String,
    val lessonsFew: String,
    val lessonsMany: String,
    val noLessons: String,
)

private data class WidgetPayload(
    val locale: Locale,
    val labels: WidgetLabels,
    val lessons: List<WidgetLesson>,
)

/** A lesson as the widget shows it: a double lesson becomes one block. */
private data class LessonBlock(
    val subject: String,
    val room: String,
    val teacher: String,
    val start: Long,
    val end: Long,
    val substitution: Boolean,
    val count: Int,
)

/** The drawables and colours of one widget theme. */
private class WidgetPalette(
    val background: Int,
    val pill: Int,
    val line: Int,
    val dotOn: Int,
    val dotMid: Int,
    val dotOff: Int,
    val text: Int,
    val text2: Int,
    val warning: Int,
) {
    companion object {
        fun of(theme: String): WidgetPalette {
            // Wallpaper colours exist from Android 12.
            val effective = if (theme == "system" && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) "brand" else theme
            return when (effective) {
                "system" -> WidgetPalette(
                    R.drawable.widget_system_bg, R.drawable.widget_system_pill, R.drawable.widget_system_line,
                    R.drawable.widget_system_dot_on, R.drawable.widget_system_dot_mid, R.drawable.widget_system_dot_off,
                    R.color.widget_system_text, R.color.widget_system_text2, R.color.widget_system_warn,
                )
                "light" -> WidgetPalette(
                    R.drawable.widget_light_bg, R.drawable.widget_light_pill, R.drawable.widget_light_line,
                    R.drawable.widget_light_dot_on, R.drawable.widget_light_dot_mid, R.drawable.widget_light_dot_off,
                    R.color.widget_light_text, R.color.widget_light_text2, R.color.widget_light_warn,
                )
                "dark" -> WidgetPalette(
                    R.drawable.widget_dark_bg, R.drawable.widget_dark_pill, R.drawable.widget_dark_line,
                    R.drawable.widget_dark_dot_on, R.drawable.widget_dark_dot_mid, R.drawable.widget_dark_dot_off,
                    R.color.widget_dark_text, R.color.widget_dark_text2, R.color.widget_dark_warn,
                )
                "black" -> WidgetPalette(
                    R.drawable.widget_black_bg, R.drawable.widget_black_pill, R.drawable.widget_black_line,
                    R.drawable.widget_black_dot_on, R.drawable.widget_black_dot_mid, R.drawable.widget_black_dot_off,
                    R.color.widget_black_text, R.color.widget_black_text2, R.color.widget_black_warn,
                )
                "translucent" -> WidgetPalette(
                    R.drawable.widget_translucent_bg, R.drawable.widget_translucent_pill,
                    R.drawable.widget_translucent_line, R.drawable.widget_translucent_dot_on,
                    R.drawable.widget_translucent_dot_mid, R.drawable.widget_translucent_dot_off,
                    R.color.widget_translucent_text, R.color.widget_translucent_text2,
                    R.color.widget_translucent_warn,
                )
                else -> WidgetPalette(
                    R.drawable.widget_brand_bg, R.drawable.widget_brand_pill, R.drawable.widget_brand_line,
                    R.drawable.widget_brand_dot_on, R.drawable.widget_brand_dot_mid, R.drawable.widget_brand_dot_off,
                    R.color.widget_brand_text, R.color.widget_brand_text2, R.color.widget_brand_warn,
                )
            }
        }
    }
}

/** The views of the main lesson block, which the square and wide layouts share. */
private class MainIds(
    val top: Int,
    val pill: Int,
    val flag: Int,
    val dots: Int,
    val subject: Int,
    val time: Int,
    val countdown: Int,
    val detail: Int,
)

private val SMALL_IDS = MainIds(
    R.id.small_top, R.id.small_pill, R.id.small_flag, R.id.small_dots,
    R.id.small_subject, R.id.small_time, R.id.small_countdown, R.id.small_detail,
)

private val WIDE_IDS = MainIds(
    R.id.wide_top, R.id.wide_pill, R.id.wide_flag, R.id.wide_dots,
    R.id.wide_subject, R.id.wide_time, R.id.wide_countdown, R.id.wide_detail,
)

/** A subject text size and how many lines it needs and may take. */
private class SubjectFit(val sp: Float, val lines: Int, val maxLines: Int, val height: Float)

/**
 * Builds the widget for a given size in dp.
 *
 * RemoteViews cannot measure text, so the subject's size and lines and the
 * number of listed lessons come from the space each text style needs at the
 * phone's font scale. That keeps every line whole, shrinks a long subject
 * before cutting it, and leaves no large gaps.
 */
private class LessonLayouts(
    private val context: Context,
    private val payload: WidgetPayload?,
    private val config: WidgetConfig,
    private val now: Long,
) {
    private val zone = ZoneId.systemDefault()
    private val today = LocalDate.now(zone)
    private val timeFormat = DateFormat.getTimeFormat(context)
    private val locale = payload?.locale ?: Locale.getDefault()
    private val fontScale = context.resources.configuration.fontScale
    private val palette = WidgetPalette.of(config.theme)
    private val labels = payload?.labels

    private val blocks = payload?.lessons?.let(::mergeBlocks).orEmpty()
    private val remaining = blocks.filter { it.end > now }
    private val main = remaining.firstOrNull()
    private val later = if (config.showNextLessons) remaining.drop(1) else emptyList()
    private val ongoing = main != null && main.start <= now
    private val onBreak = run {
        val previous = blocks.lastOrNull { it.end <= now }
        !ongoing && main != null && previous != null &&
            date(previous.end) == today && date(main.start) == today &&
            main.start - previous.end <= MAX_BREAK
    }
    private val countdownTarget: Long? = when {
        !config.showCountdown || main == null -> null
        ongoing -> main.end
        main.start - now <= COUNTDOWN_WINDOW -> main.start
        else -> null
    }
    private val dayBlocks = main?.let { lesson -> blocks.filter { date(it.start) == date(lesson.start) } }.orEmpty()
    private val flagged = config.highlightSubstitutions && main?.substitution == true

    fun build(width: Float, height: Float): RemoteViews {
        val main = main
        val views = when {
            payload == null || main == null -> empty()
            height < smallMinHeight() -> compact(main, width, height)
            width >= WIDE_MIN_WIDTH -> wide(main, width, height)
            else -> small(main, width, height)
        }
        views.setInt(android.R.id.background, "setBackgroundResource", palette.background)
        views.setOnClickPendingIntent(android.R.id.background, openApp())
        return views
    }

    // Layouts

    private fun empty() = RemoteViews(context.packageName, R.layout.widget_empty).apply {
        setTextViewText(
            R.id.empty_text,
            labels?.noLessons?.takeIf { it.isNotEmpty() } ?: context.getString(R.string.widget_open_app),
        )
        setInt(R.id.empty_pill, "setBackgroundResource", palette.pill)
        color(R.id.empty_pill, palette.text)
        color(R.id.empty_text, palette.text)
    }

    private fun compact(main: LessonBlock, width: Float, height: Float) =
        RemoteViews(context.packageName, R.layout.widget_compact).apply {
            // Below this height only the time and the subject fit, one line each.
            val twoLines = height >= 2 * COMPACT_VERTICAL_PADDING + line(16f) + 3 + line(13f)
            setTextViewText(R.id.compact_start, time(main.start))
            setTextViewText(R.id.compact_end, time(main.end))
            setViewVisibility(R.id.compact_end, visibleIf(twoLines))
            setTextViewText(R.id.compact_subject, main.subject)
            setViewVisibility(R.id.compact_second_line, visibleIf(twoLines))

            val details = detailParts(main, substitutionLabel = true)
            val target = countdownTarget
            if (target != null) {
                startCountdown(this, R.id.compact_countdown, target)
                setTextViewText(R.id.compact_detail, if (details.isEmpty()) "" else " · ${joined(details)}")
            } else {
                setViewVisibility(R.id.compact_countdown, View.GONE)
                setTextViewText(R.id.compact_detail, joined(listOf(status()) + details))
            }

            val next = later.firstOrNull()
            val showNext = next != null && width >= COMPACT_NEXT_MIN_WIDTH
            setViewVisibility(R.id.compact_divider, visibleIf(showNext))
            setViewVisibility(R.id.compact_later, visibleIf(showNext))
            if (next != null && showNext) {
                setTextViewText(R.id.compact_later_time, rowTime(next, main))
                setViewVisibility(R.id.compact_later_time, visibleIf(twoLines))
                setTextViewText(R.id.compact_later_subject, next.subject)
            }

            setInt(R.id.compact_bar, "setBackgroundResource", if (flagged) R.drawable.widget_flag_bar else palette.line)
            setInt(R.id.compact_divider, "setBackgroundResource", palette.line)
            listOf(R.id.compact_start, R.id.compact_subject, R.id.compact_countdown, R.id.compact_later_subject)
                .forEach { color(it, palette.text) }
            listOf(R.id.compact_end, R.id.compact_detail, R.id.compact_later_time)
                .forEach { color(it, palette.text2) }
        }

    private fun small(main: LessonBlock, width: Float, height: Float) =
        RemoteViews(context.packageName, R.layout.widget_small).apply {
            val contentWidth = width - 2 * PADDING
            fillMain(this, SMALL_IDS, main, contentWidth)
            val available = height - 2 * PADDING - mainFixedHeight(main)
            val fit = fitSubject(main.subject, contentWidth, available)
            val rows = if (later.isEmpty()) {
                0
            } else {
                floor((available - fit.height - LIST_OVERHEAD + ROW_PADDING) / rowHeight()).toInt()
                    .coerceIn(0, min(MAX_SMALL_ROWS, later.size))
            }
            applyFit(this, R.id.small_subject, fit, if (rows > 0) fit.lines else fit.maxLines)

            setViewVisibility(R.id.small_spacer_middle, visibleIf(rows == 0))
            setViewVisibility(R.id.small_gap, visibleIf(rows > 0))
            setViewVisibility(R.id.small_spacer_bottom, visibleIf(rows > 0))
            setViewVisibility(R.id.small_list_block, visibleIf(rows > 0))
            setInt(R.id.small_list_divider, "setBackgroundResource", palette.line)
            removeAllViews(R.id.small_rows)
            val spare = available - fit.height - LIST_OVERHEAD - rows * rowHeight() + ROW_PADDING
            addRows(this, R.id.small_rows, main, rows, contentWidth, spare, firstPadded = true)
        }

    private fun wide(main: LessonBlock, width: Float, height: Float) =
        RemoteViews(context.packageName, R.layout.widget_wide).apply {
            val content = height - 2 * PADDING
            // The first row has no top padding, so it lines up with the label.
            val rows = floor((content + ROW_PADDING) / rowHeight()).toInt()
                .coerceIn(0, min(MAX_WIDE_ROWS, later.size))
            val columnWidth = if (rows > 0) (width - 2 * PADDING - WIDE_DIVIDER) / 2 else width - 2 * PADDING
            fillMain(this, WIDE_IDS, main, columnWidth)
            val fit = fitSubject(main.subject, columnWidth, content - mainFixedHeight(main))
            applyFit(this, R.id.wide_subject, fit, fit.maxLines)

            setViewVisibility(R.id.wide_divider, visibleIf(rows > 0))
            setViewVisibility(R.id.wide_rows, visibleIf(rows > 0))
            setInt(R.id.wide_divider, "setBackgroundResource", palette.line)
            removeAllViews(R.id.wide_rows)
            val spare = content - rows * rowHeight() + ROW_PADDING
            addRows(this, R.id.wide_rows, main, rows, columnWidth, spare, firstPadded = false)
        }

    /** The label row, subject, time, countdown and details of the main lesson. */
    private fun fillMain(views: RemoteViews, ids: MainIds, main: LessonBlock, contentWidth: Float) {
        val status = status()
        views.setTextViewText(ids.pill, status)
        views.setInt(ids.pill, "setBackgroundResource", palette.pill)
        views.color(ids.pill, palette.text)

        // The label row holds the status, the substitution flag and the dots;
        // what does not fit is left out, the flag's text moving to the details.
        val flagText = labels?.substitution.orEmpty()
        val pillWidth = labelWidth(status)
        val flagWidth = if (flagged && flagText.isNotEmpty()) 6 + labelWidth(flagText) else 0f
        val showFlag = flagWidth > 0 && pillWidth + flagWidth <= contentWidth
        val showDots = config.showProgress && dayBlocks.size in 2..MAX_DOTS &&
            pillWidth + (if (showFlag) flagWidth else 0f) + 6 + dayBlocks.size * DOT_WIDTH <= contentWidth
        views.setViewVisibility(ids.flag, visibleIf(showFlag))
        if (showFlag) views.setTextViewText(ids.flag, flagText)
        views.setViewVisibility(ids.dots, visibleIf(showDots))
        views.removeAllViews(ids.dots)
        if (showDots) {
            val current = dayBlocks.indexOf(main)
            dayBlocks.forEachIndexed { index, _ ->
                val dot = RemoteViews(context.packageName, R.layout.widget_dot)
                dot.setInt(
                    R.id.dot,
                    "setBackgroundResource",
                    when {
                        index < current -> palette.dotMid
                        index == current -> palette.dotOn
                        else -> palette.dotOff
                    },
                )
                views.addView(ids.dots, dot)
            }
        }

        views.setTextViewText(ids.subject, main.subject)
        views.color(ids.subject, palette.text)
        views.setTextViewText(ids.time, "${time(main.start)}–${time(main.end)}")
        views.color(ids.time, palette.text)

        val target = countdownTarget
        if (target != null) {
            startCountdown(views, ids.countdown, target)
            views.color(ids.countdown, palette.text)
        } else {
            views.setViewVisibility(ids.countdown, View.GONE)
        }

        val details = joined(detailParts(main, substitutionLabel = !showFlag, teacher = config.showTeacher))
        views.setTextViewText(ids.detail, details)
        views.setViewVisibility(ids.detail, visibleIf(details.isNotEmpty()))
        views.color(ids.detail, palette.text2)
    }

    /**
     * Adds [count] following lessons. A long subject gets a second line while
     * [spare] height lasts.
     */
    private fun addRows(
        views: RemoteViews,
        container: Int,
        main: LessonBlock,
        count: Int,
        width: Float,
        spare: Float,
        firstPadded: Boolean,
    ) {
        var extra = spare
        later.take(count).forEachIndexed { index, lesson ->
            val row = RemoteViews(context.packageName, R.layout.widget_lesson_row)
            row.setTextViewText(R.id.row_meta, rowMeta(lesson, main))
            row.setTextViewText(R.id.row_subject, lesson.subject)
            val warn = config.highlightSubstitutions && lesson.substitution
            row.color(R.id.row_meta, if (warn) palette.warning else palette.text2)
            row.color(R.id.row_subject, palette.text)
            if (wrappedLines(lesson.subject, width, 13f) > 1 && extra >= line(13f)) {
                row.setInt(R.id.row_subject, "setMaxLines", 2)
                extra -= line(13f)
            }
            if (index == 0 && !firstPadded) row.setViewPadding(R.id.row_root, 0, 0, 0, 0)
            views.addView(container, row)
        }
    }

    private fun startCountdown(views: RemoteViews, id: Int, target: Long) {
        val template = (if (ongoing) labels?.endsIn else labels?.startsIn).orEmpty()
        val format = when {
            template.contains("%s") -> template
            template.isEmpty() -> "%s"
            else -> "$template %s"
        }
        views.setViewVisibility(id, View.VISIBLE)
        views.setChronometer(id, SystemClock.elapsedRealtime() + (target - now), format, true)
        views.setChronometerCountDown(id, true)
    }

    private fun applyFit(views: RemoteViews, id: Int, fit: SubjectFit, maxLines: Int) {
        views.setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, fit.sp)
        views.setInt(id, "setMaxLines", maxLines)
    }

    private fun openApp(): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    // Lessons

    /** Joins the same subject in a row into one block when the widget asks for it. */
    private fun mergeBlocks(lessons: List<WidgetLesson>): List<LessonBlock> {
        val result = mutableListOf<LessonBlock>()
        for (lesson in lessons) {
            val last = result.lastOrNull()
            if (config.mergeDoubleLessons && last != null && last.subject == lesson.subject &&
                date(last.start) == date(lesson.start) && lesson.start - last.end in 0..MAX_MERGE_GAP
            ) {
                result[result.lastIndex] = last.copy(
                    end = lesson.end,
                    count = last.count + 1,
                    substitution = last.substitution || lesson.substitution,
                    room = listOf(last.room, lesson.room).filter { it.isNotEmpty() }.distinct().joinToString("/"),
                )
            } else {
                result += LessonBlock(
                    lesson.subject, lesson.room, lesson.teacher, lesson.start, lesson.end, lesson.substitution, 1,
                )
            }
        }
        return result
    }

    // Texts

    /** "Now", "Break", "Next lesson", or the day when the lesson is not today. */
    private fun status(): String {
        val labels = labels ?: return ""
        val main = main ?: return ""
        return when {
            ongoing -> labels.now
            onBreak -> labels.onBreak.ifEmpty { labels.next }
            else -> day(main, TextStyle.FULL_STANDALONE) ?: labels.next
        }
    }

    private fun detailParts(lesson: LessonBlock, substitutionLabel: Boolean, teacher: Boolean = false) =
        listOfNotNull(
            lessonCount(lesson),
            room(lesson).takeIf { config.showRoom },
            lesson.teacher.takeIf { teacher && it.isNotEmpty() },
            labels?.substitution?.takeIf { substitutionLabel && lesson.substitution && it.isNotEmpty() },
        )

    /** "2 lessons" for a double lesson, with the language's plural form. */
    private fun lessonCount(lesson: LessonBlock): String? {
        if (lesson.count < 2) return null
        val n = lesson.count
        val few = n % 10 in 2..4 && n % 100 !in 12..14
        val template = (if (few) labels?.lessonsFew else labels?.lessonsMany).orEmpty()
        return if (template.isEmpty()) null else template.replace("%d", n.toString())
    }

    private fun day(lesson: LessonBlock, style: TextStyle): String? {
        val date = date(lesson.start)
        return when (date) {
            today -> null
            today.plusDays(1) -> labels?.tomorrow?.takeIf { it.isNotEmpty() } ?: weekday(date, style)
            else -> weekday(date, style)
        }
    }

    private fun weekday(date: LocalDate, style: TextStyle) =
        date.dayOfWeek.getDisplayName(style, locale)
            .replaceFirstChar { if (it.isLowerCase()) it.titlecase(locale) else it.toString() }

    /** A later lesson's start, with its day when that differs from the main lesson's. */
    private fun rowTime(lesson: LessonBlock, main: LessonBlock): String {
        val start = if (lesson.count > 1) "${time(lesson.start)}–${time(lesson.end)}" else time(lesson.start)
        if (date(lesson.start) == date(main.start)) return start
        return "${day(lesson, TextStyle.SHORT_STANDALONE) ?: ""} $start".trim()
    }

    private fun rowMeta(lesson: LessonBlock, main: LessonBlock) = joined(
        listOfNotNull(
            rowTime(lesson, main),
            room(lesson).takeIf { config.showRoom },
            labels?.substitution?.takeIf { lesson.substitution && it.isNotEmpty() },
        ),
    )

    private fun room(lesson: LessonBlock) = if (lesson.room.isEmpty()) null else "s. ${lesson.room}"

    private fun time(millis: Long): String = timeFormat.format(Date(millis))

    private fun date(millis: Long): LocalDate = Instant.ofEpochMilli(millis).atZone(zone).toLocalDate()

    private fun joined(parts: List<String?>) = parts.filterNotNull().filter { it.isNotEmpty() }.joinToString(" · ")

    private fun RemoteViews.color(id: Int, colorRes: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Resolved by the launcher, so day and night variants follow the system.
            setColorStateList(id, "setTextColor", colorRes)
        } else {
            setTextColor(id, context.getColor(colorRes))
        }
    }

    // Sizes in dp

    /** Height of one line of text in a style of [sp] size, with room to spare. */
    private fun line(sp: Float) = sp * fontScale * 1.3f

    private fun subjectLine(sp: Float) = line(sp) + 1

    private fun rowHeight() = ROW_PADDING + line(12f) + 2 + line(13f)

    /** Width of an upper-case label pill. */
    private fun labelWidth(text: String) = text.length * 10f * fontScale * 0.68f + 16

    /** Everything in the main block except the subject. */
    private fun mainFixedHeight(main: LessonBlock): Float {
        val pill = line(10f) + 6
        val countdown = if (countdownTarget != null) 3 + line(12f) else 0f
        val detail = if (detailParts(main, substitutionLabel = true, teacher = config.showTeacher).isEmpty()) {
            0f
        } else {
            3 + line(12f)
        }
        return pill + 8 + 8 + line(14f) + countdown + detail
    }

    /** The square layout needs room for at least one subject line. */
    private fun smallMinHeight() =
        2 * PADDING + 8 + 8 + line(10f) + 6 + line(14f) + 3 + line(12f) + subjectLine(16f)

    /**
     * The largest subject size, down to 13sp, whose lines fit in [height];
     * at 13sp the text may still be cut.
     */
    private fun fitSubject(text: String, width: Float, height: Float): SubjectFit {
        for (sp in SUBJECT_SIZES) {
            val lineHeight = subjectLine(sp)
            val maxLines = floor(height / lineHeight).toInt().coerceIn(1, MAX_SUBJECT_LINES)
            val lines = wrappedLines(text, width, sp)
            if (lines <= maxLines || sp == SUBJECT_SIZES.last()) {
                val shown = min(lines, maxLines)
                return SubjectFit(sp, shown, maxLines, shown * lineHeight)
            }
        }
        error("unreachable")
    }

    /** Lines [text] takes at [sp] in [width], wrapping between words. */
    private fun wrappedLines(text: String, width: Float, sp: Float): Int {
        val perLine = floor(width / (sp * fontScale * CHAR_WIDTH)).toInt().coerceAtLeast(4)
        var lines = 1
        var used = 0
        for (word in text.split(' ').filter { it.isNotEmpty() }) {
            val length = word.length
            if (used == 0) {
                lines += (length - 1) / perLine
                used = (length - 1) % perLine + 1
            } else if (used + 1 + length <= perLine) {
                used += 1 + length
            } else {
                lines += 1 + (length - 1) / perLine
                used = (length - 1) % perLine + 1
            }
        }
        return lines
    }

    private fun visibleIf(visible: Boolean) = if (visible) View.VISIBLE else View.GONE

    private companion object {
        const val PADDING = 16f
        const val COMPACT_VERTICAL_PADDING = 8f
        const val ROW_PADDING = 8f
        const val LIST_OVERHEAD = 5f
        const val WIDE_DIVIDER = 29f
        const val WIDE_MIN_WIDTH = 260f
        const val COMPACT_NEXT_MIN_WIDTH = 280f
        const val MAX_SMALL_ROWS = 4
        const val MAX_WIDE_ROWS = 5
        const val MAX_DOTS = 10
        const val DOT_WIDTH = 10f
        const val MAX_SUBJECT_LINES = 4
        const val MAX_BREAK = 3 * 60 * 60 * 1000L
        const val MAX_MERGE_GAP = 15 * 60 * 1000L

        /** Average width of a bold letter, in em; a little generous so lines are not cut. */
        const val CHAR_WIDTH = 0.58f
        val SUBJECT_SIZES = listOf(16f, 15f, 14f, 13f)
    }
}
