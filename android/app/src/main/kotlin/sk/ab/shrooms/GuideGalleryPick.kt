package sk.ab.shrooms

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import kotlin.math.max
import kotlin.math.roundToInt

/// Copies a photo-picker item into the cache and bakes its orientation into
/// the pixels. Flutter draws a file as stored, so a sensor orientation tag
/// would show the photo sideways.
/// A JPEG that already fits and is already upright is kept byte for byte,
/// so its GPS stays until the find has read it. A rewritten JPEG keeps the
/// place and date, and the orientation tag is set back to normal.
/// A photo that cannot be re-encoded is kept for that same read.
/// Photos keeps a camera name such as IMG_20110806_081932 after Picasa has
/// dropped the EXIF date. That name is written back as the date, and the
/// gallery's date taken is used when the picker name has none. The cache
/// file keeps the name so the find can still read it.
object GuideGalleryPick {
    private const val maxDecodedPixels = 8_000_000L
    private val cameraStamp = Regex(
        """(?:^|[^0-9])(\d{4})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})""",
    )
    private val placeTags = arrayOf(
        ExifInterface.TAG_GPS_LATITUDE,
        ExifInterface.TAG_GPS_LATITUDE_REF,
        ExifInterface.TAG_GPS_LONGITUDE,
        ExifInterface.TAG_GPS_LONGITUDE_REF,
        ExifInterface.TAG_GPS_ALTITUDE,
        ExifInterface.TAG_GPS_ALTITUDE_REF,
        ExifInterface.TAG_DATETIME,
        ExifInterface.TAG_DATETIME_ORIGINAL,
    )

    fun save(context: Context, uri: Uri, maxWidth: Int): String? {
        val dir = File(context.cacheDir, "guide-pick").apply { mkdirs() }
        val extension = extensionOf(context, uri)
        val displayName = displayName(context, uri)
        val stem = fileStem(displayName)
        val original = File(dir, cacheName(stem, extension))
        var scaled: File? = null
        try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(original).use { output -> input.copyTo(output) }
            } ?: return abandon(original, null)
            if (!original.exists() || original.length() == 0L) {
                return abandon(original, null)
            }
            val orientation = readOrientation(original)
            val bounds = boundsOf(original)
            val uprightWidth =
                displayedWidth(bounds.outWidth, bounds.outHeight, orientation)
            val tooWide = maxWidth > 0 && uprightWidth > maxWidth
            if (isJpeg(original) && !tooWide && !needsTurn(orientation)) {
                return finish(context, uri, displayName, original)
            }
            val written = transcode(original, maxWidth, orientation, stem)
            if (written == null) return finish(context, uri, displayName, original)
            scaled = written
            copyPlace(original, written)
            original.delete()
            return finish(context, uri, displayName, written)
        } catch (error: Throwable) {
            Log.e("GuideGalleryPick", "save failed", error)
            original.delete()
            scaled?.delete()
            return null
        }
    }

    private fun abandon(original: File, scaled: File?): String? {
        original.delete()
        scaled?.delete()
        return null
    }

    private fun extensionOf(context: Context, uri: Uri): String {
        val mime = context.contentResolver.getType(uri)
        val mapped = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime)
        return if (mapped.isNullOrEmpty()) "jpg" else mapped.lowercase()
    }

    private fun isJpeg(file: File): Boolean {
        file.inputStream().use { input ->
            val header = ByteArray(3)
            if (input.read(header) != 3) return false
            return header[0] == 0xFF.toByte() &&
                header[1] == 0xD8.toByte() &&
                header[2] == 0xFF.toByte()
        }
    }

    private fun boundsOf(file: File): BitmapFactory.Options {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        return bounds
    }

    private fun readOrientation(file: File): Int {
        return try {
            ExifInterface(file.absolutePath).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } catch (_: Throwable) {
            ExifInterface.ORIENTATION_NORMAL
        }
    }

    private fun needsTurn(orientation: Int): Boolean {
        return when (orientation) {
            ExifInterface.ORIENTATION_UNDEFINED,
            ExifInterface.ORIENTATION_NORMAL,
            -> false
            else -> true
        }
    }

    private fun swapsAxes(orientation: Int): Boolean {
        return when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90,
            ExifInterface.ORIENTATION_ROTATE_270,
            ExifInterface.ORIENTATION_TRANSPOSE,
            ExifInterface.ORIENTATION_TRANSVERSE,
            -> true
            else -> false
        }
    }

    private fun displayedWidth(width: Int, height: Int, orientation: Int): Int {
        if (width <= 0 || height <= 0) return 0
        return if (swapsAxes(orientation)) height else width
    }

    private fun transcode(
        original: File,
        maxWidth: Int,
        orientation: Int,
        stem: String,
    ): File? {
        val bounds = boundsOf(original)
        val width = bounds.outWidth
        val height = bounds.outHeight
        if (width <= 0 || height <= 0) return null
        val sample = sampleSize(
            width,
            height,
            displayedWidth(width, height, orientation),
            maxWidth,
        )
        val decoded = BitmapFactory.decodeFile(
            original.absolutePath,
            BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: return null
        val upright = applyOrientation(decoded, orientation)
        val target = scaleToWidth(upright, maxWidth)
        val out = File(original.parentFile, cacheName(stem, "jpg"))
        try {
            FileOutputStream(out).use { stream ->
                if (!target.compress(Bitmap.CompressFormat.JPEG, 92, stream)) {
                    out.delete()
                    return null
                }
            }
            return out
        } catch (error: Throwable) {
            out.delete()
            throw error
        } finally {
            if (target !== upright) target.recycle()
            if (upright !== decoded) upright.recycle()
            decoded.recycle()
        }
    }

    /// EXIF orientation, applied in the order the tag describes.
    private fun applyOrientation(bitmap: Bitmap, orientation: Int): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> {
                matrix.setRotate(180f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.setRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.setRotate(-90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(-90f)
            else -> return bitmap
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    /// Power-of-two [BitmapFactory.Options.inSampleSize]. The decoded bitmap
    /// stays near [maxWidth] and under [maxDecodedPixels], so a large photo
    /// does not throw [OutOfMemoryError] on the way to the picker result.
    private fun sampleSize(width: Int, height: Int, displayed: Int, maxWidth: Int): Int {
        if (width <= 0 || height <= 0) return 1
        var sample = 1
        val target = if (maxWidth > 0) maxWidth else 2048
        val along = if (maxWidth > 0) displayed else max(width, height)
        if (along > target) {
            while (sample < 128 && along / (sample * 2) > target) sample *= 2
        }
        while (sample < 128 &&
            (width.toLong() / sample) * (height.toLong() / sample) > maxDecodedPixels
        ) {
            sample *= 2
        }
        return sample
    }

    private fun scaleToWidth(bitmap: Bitmap, maxWidth: Int): Bitmap {
        if (maxWidth <= 0 || bitmap.width <= maxWidth) return bitmap
        val height = max(1, (bitmap.height * (maxWidth.toDouble() / bitmap.width)).roundToInt())
        return Bitmap.createScaledBitmap(bitmap, maxWidth, height, true)
    }

    /// Writes a missing EXIF date from the camera filename, then from the
    /// gallery's date taken. The filename clock is the one in
    /// IMG_20110806_081932. The pattern matches photoDateFromName.
    private fun finish(context: Context, uri: Uri, displayName: String?, file: File): String {
        rememberGalleryDate(context, uri, displayName, file)
        return file.absolutePath
    }

    private fun rememberGalleryDate(
        context: Context,
        uri: Uri,
        displayName: String?,
        file: File,
    ) {
        if (!file.exists() || !isJpeg(file)) return
        try {
            val exif = ExifInterface(file.absolutePath)
            if (exifDate(exif) != null) return
            val wall = wallClock(displayName) ?: wallClockFromTaken(context, uri) ?: return
            exif.setAttribute(ExifInterface.TAG_DATETIME_ORIGINAL, wall)
            exif.setAttribute(ExifInterface.TAG_DATETIME, wall)
            exif.saveAttributes()
        } catch (_: Throwable) {
        }
    }

    private fun exifDate(exif: ExifInterface): String? {
        val tags = arrayOf(
            ExifInterface.TAG_DATETIME_ORIGINAL,
            ExifInterface.TAG_DATETIME_DIGITIZED,
            ExifInterface.TAG_DATETIME,
        )
        for (tag in tags) {
            val value = exif.getAttribute(tag)?.trim().orEmpty()
            if (value.isNotEmpty()) return value
        }
        return null
    }

    private fun displayName(context: Context, uri: Uri): String? {
        return try {
            context.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (!cursor.moveToFirst()) return null
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index < 0 || cursor.isNull(index)) return null
                cursor.getString(index)?.trim()?.ifEmpty { null }
            }
        } catch (_: Throwable) {
            null
        }
    }

    /// `datetaken` is milliseconds. A few galleries still store seconds.
    private fun wallClockFromTaken(context: Context, uri: Uri): String? {
        val millis = try {
            context.contentResolver.query(uri, arrayOf("datetaken"), null, null, null)
                ?.use { cursor ->
                    if (!cursor.moveToFirst()) return null
                    val index = cursor.getColumnIndex("datetaken")
                    if (index < 0 || cursor.isNull(index)) return null
                    epochMillis(cursor.getLong(index))
                }
        } catch (_: Throwable) {
            null
        } ?: return null
        val format = SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US)
        format.timeZone = TimeZone.getDefault()
        return format.format(Date(millis))
    }

    private fun epochMillis(value: Long): Long? {
        if (value <= 0L) return null
        val millis = if (value < 100_000_000_000L) value * 1000L else value
        val earliest = 315532800000L
        val latest = System.currentTimeMillis() + 24L * 60L * 60L * 1000L
        if (millis < earliest || millis > latest) return null
        return millis
    }

    private fun cacheName(stem: String, extension: String): String {
        val id = UUID.randomUUID().toString()
        val ext = extension.ifEmpty { "jpg" }
        if (stem.isEmpty()) return "$id.$ext"
        return "${id}_$stem.$ext"
    }

    private fun fileStem(display: String?): String {
        if (display.isNullOrBlank()) return ""
        val base = display.substringAfterLast('/').substringAfterLast('\\')
        val noExt = if (base.contains('.')) base.substringBeforeLast('.') else base
        val cleaned = noExt.map { ch ->
            if (ch.isLetterOrDigit() || ch == '_' || ch == '-' || ch == '.') ch else '_'
        }.joinToString("").trim('_', '.').take(80)
        return cleaned
    }

    /// `YYYYMMDD_HHMMSS` or `YYYYMMDD-HHMMSS` in a camera filename.
    private fun wallClock(name: String?): String? {
        if (name.isNullOrEmpty()) return null
        val base = name.substringAfterLast('/').substringAfterLast('\\')
        val match = cameraStamp.find(base) ?: return null
        val year = match.groupValues[1].toIntOrNull() ?: return null
        val month = match.groupValues[2].toIntOrNull() ?: return null
        val day = match.groupValues[3].toIntOrNull() ?: return null
        val hour = match.groupValues[4].toIntOrNull() ?: return null
        val minute = match.groupValues[5].toIntOrNull() ?: return null
        val second = match.groupValues[6].toIntOrNull() ?: return null
        if (!validClock(year, month, day, hour, minute, second)) return null
        return "%04d:%02d:%02d %02d:%02d:%02d".format(
            Locale.US,
            year,
            month,
            day,
            hour,
            minute,
            second,
        )
    }

    private fun validClock(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
    ): Boolean {
        if (year < 1980 || year > Calendar.getInstance().get(Calendar.YEAR) + 1) return false
        if (month !in 1..12 || day !in 1..31) return false
        if (hour !in 0..23 || minute !in 0..59 || second !in 0..59) return false
        return try {
            val calendar = Calendar.getInstance()
            calendar.clear()
            calendar.isLenient = false
            calendar.set(year, month - 1, day, hour, minute, second)
            calendar.timeInMillis
            true
        } catch (_: IllegalArgumentException) {
            false
        }
    }

    private fun copyPlace(from: File, to: File) {
        try {
            val source = ExifInterface(from.absolutePath)
            val dest = ExifInterface(to.absolutePath)
            for (tag in placeTags) {
                val value = source.getAttribute(tag) ?: continue
                dest.setAttribute(tag, value)
            }
            dest.setAttribute(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL.toString(),
            )
            dest.saveAttributes()
        } catch (_: Throwable) {
        }
    }
}
