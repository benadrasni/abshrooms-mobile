package sk.ab.shrooms

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pickerResult: MethodChannel.Result? = null
    private var pickerMaxWidth = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sk.ab.shrooms/photo")
            .setMethodCallHandler { call, result ->
                if (call.method != "pick") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pickerResult != null) {
                    result.error("busy", "photo picker already open", null)
                    return@setMethodCallHandler
                }
                pickerMaxWidth = call.argument<Number>("maxWidth")?.toInt() ?: 0
                pickerResult = result
                if (needsLocationPermission()) {
                    @Suppress("DEPRECATION")
                    requestPermissions(
                        arrayOf(Manifest.permission.ACCESS_MEDIA_LOCATION),
                        requestLocation,
                    )
                    return@setMethodCallHandler
                }
                launchPicker()
            }
    }

    private fun needsLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        return checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
    }

    @Deprecated("FlutterActivity is not a ComponentActivity")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == requestLocation) {
            // The picker still opens. The person can leave the place out.
            launchPicker()
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun launchPicker() {
        if (pickerResult == null) return
        val intent = Intent(MediaStore.ACTION_PICK_IMAGES)
            .setType("image/*")
            .putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, 1)
        // API 37.1 name. This compile SDK has no constant for it yet.
        // The photo picker reads the string and asks whether to keep
        // location. The person's choice is final.
        intent.putExtra(
            "android.provider.extra.REQUEST_LOCATION_METADATA_ACCESS",
            true,
        )
        try {
            // FlutterActivity is not a ComponentActivity, so the
            // activity-result registry is not available.
            @Suppress("DEPRECATION")
            startActivityForResult(intent, requestPick)
        } catch (error: Exception) {
            // resolveActivity is the wrong probe: from API 30 the
            // photo picker is hidden from package queries, so it
            // looks missing on phones that have it.
            val pending = pickerResult
            pickerResult = null
            if (error is ActivityNotFoundException) {
                pending?.error("unavailable", "photo picker missing", null)
            } else {
                Log.e("GuideGalleryPick", "launch failed", error)
                pending?.error("failed", error.message, null)
            }
        }
    }

    private fun pickedUri(data: Intent?): Uri? {
        data?.data?.let { return it }
        val clip = data?.clipData ?: return null
        if (clip.itemCount == 0) return null
        return clip.getItemAt(0).uri
    }

    @Deprecated("FlutterActivity is not a ComponentActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == requestPick) {
            finishPick(resultCode, pickedUri(data))
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun finishPick(resultCode: Int, uri: Uri?) {
        val pending = pickerResult ?: return
        pickerResult = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.success(null)
            return
        }
        val maxWidth = pickerMaxWidth
        val app = applicationContext
        Thread {
            val path = try {
                GuideGalleryPick.save(app, uri, maxWidth)
            } catch (error: Throwable) {
                Log.e("GuideGalleryPick", "save failed", error)
                null
            }
            runOnUiThread {
                val delivered = if (isDestroyed) {
                    if (path != null) File(path).delete()
                    null
                } else {
                    path
                }
                try {
                    pending.success(delivered)
                } catch (error: Throwable) {
                    Log.e("GuideGalleryPick", "result failed", error)
                }
            }
        }.start()
    }

    override fun onDestroy() {
        if (isFinishing) {
            val pending = pickerResult
            pickerResult = null
            try {
                pending?.success(null)
            } catch (error: Throwable) {
                Log.e("GuideGalleryPick", "result failed", error)
            }
        }
        super.onDestroy()
    }

    companion object {
        private const val requestPick = 48121
        private const val requestLocation = 48122
    }
}
