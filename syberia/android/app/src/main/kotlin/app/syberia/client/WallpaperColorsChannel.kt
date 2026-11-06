package app.syberia.client

import android.content.Context
import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Gives Dart the colours Android picked from the wallpaper (Material You),
 * for the Expressive design.
 *
 * Android 14 and newer name the colour of every role, the same ones the
 * system's own screens use. Android 12 and 13 only have tonal palettes: they
 * give a colour of the main palette, from which Dart builds the scheme the
 * way Material does. Older systems have no wallpaper colours.
 */
object WallpaperColorsChannel {
    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "app.syberia.client/wallpaper_colors").setMethodCallHandler { call, result ->
            if (call.method == "colors") {
                result.success(colors(app))
            } else {
                result.notImplemented()
            }
        }
    }

    private fun colors(context: Context): Map<String, Any>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                mapOf(
                    "seed" to context.getColor(android.R.color.system_palette_key_color_primary_light),
                    "light" to roles(context, light()),
                    "dark" to roles(context, dark()),
                )
            } else {
                mapOf("seed" to context.getColor(android.R.color.system_accent1_500))
            }
        } catch (error: RuntimeException) {
            // A system that leaves out its colour resources.
            null
        }
    }

    private fun roles(context: Context, ids: Map<String, Int>): Map<String, Int> =
        ids.mapValues { (_, id) -> context.getColor(id) }

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun light(): Map<String, Int> = mapOf(
        "primary" to android.R.color.system_primary_light,
        "onPrimary" to android.R.color.system_on_primary_light,
        "primaryContainer" to android.R.color.system_primary_container_light,
        "onPrimaryContainer" to android.R.color.system_on_primary_container_light,
        "secondary" to android.R.color.system_secondary_light,
        "onSecondary" to android.R.color.system_on_secondary_light,
        "secondaryContainer" to android.R.color.system_secondary_container_light,
        "onSecondaryContainer" to android.R.color.system_on_secondary_container_light,
        "tertiary" to android.R.color.system_tertiary_light,
        "onTertiary" to android.R.color.system_on_tertiary_light,
        "tertiaryContainer" to android.R.color.system_tertiary_container_light,
        "onTertiaryContainer" to android.R.color.system_on_tertiary_container_light,
        "error" to android.R.color.system_error_light,
        "onError" to android.R.color.system_on_error_light,
        "errorContainer" to android.R.color.system_error_container_light,
        "onErrorContainer" to android.R.color.system_on_error_container_light,
        "surface" to android.R.color.system_surface_light,
        "onSurface" to android.R.color.system_on_surface_light,
        "onSurfaceVariant" to android.R.color.system_on_surface_variant_light,
        "surfaceDim" to android.R.color.system_surface_dim_light,
        "surfaceBright" to android.R.color.system_surface_bright_light,
        "surfaceContainerLowest" to android.R.color.system_surface_container_lowest_light,
        "surfaceContainerLow" to android.R.color.system_surface_container_low_light,
        "surfaceContainer" to android.R.color.system_surface_container_light,
        "surfaceContainerHigh" to android.R.color.system_surface_container_high_light,
        "surfaceContainerHighest" to android.R.color.system_surface_container_highest_light,
        "outline" to android.R.color.system_outline_light,
        "outlineVariant" to android.R.color.system_outline_variant_light,
    )

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun dark(): Map<String, Int> = mapOf(
        "primary" to android.R.color.system_primary_dark,
        "onPrimary" to android.R.color.system_on_primary_dark,
        "primaryContainer" to android.R.color.system_primary_container_dark,
        "onPrimaryContainer" to android.R.color.system_on_primary_container_dark,
        "secondary" to android.R.color.system_secondary_dark,
        "onSecondary" to android.R.color.system_on_secondary_dark,
        "secondaryContainer" to android.R.color.system_secondary_container_dark,
        "onSecondaryContainer" to android.R.color.system_on_secondary_container_dark,
        "tertiary" to android.R.color.system_tertiary_dark,
        "onTertiary" to android.R.color.system_on_tertiary_dark,
        "tertiaryContainer" to android.R.color.system_tertiary_container_dark,
        "onTertiaryContainer" to android.R.color.system_on_tertiary_container_dark,
        "error" to android.R.color.system_error_dark,
        "onError" to android.R.color.system_on_error_dark,
        "errorContainer" to android.R.color.system_error_container_dark,
        "onErrorContainer" to android.R.color.system_on_error_container_dark,
        "surface" to android.R.color.system_surface_dark,
        "onSurface" to android.R.color.system_on_surface_dark,
        "onSurfaceVariant" to android.R.color.system_on_surface_variant_dark,
        "surfaceDim" to android.R.color.system_surface_dim_dark,
        "surfaceBright" to android.R.color.system_surface_bright_dark,
        "surfaceContainerLowest" to android.R.color.system_surface_container_lowest_dark,
        "surfaceContainerLow" to android.R.color.system_surface_container_low_dark,
        "surfaceContainer" to android.R.color.system_surface_container_dark,
        "surfaceContainerHigh" to android.R.color.system_surface_container_high_dark,
        "surfaceContainerHighest" to android.R.color.system_surface_container_highest_dark,
        "outline" to android.R.color.system_outline_dark,
        "outlineVariant" to android.R.color.system_outline_variant_dark,
    )
}
