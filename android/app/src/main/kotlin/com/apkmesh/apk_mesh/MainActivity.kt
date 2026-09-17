package com.apkmesh.apk_mesh

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.res.Configuration
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Browser
import android.provider.Settings
import java.io.File
import java.util.Locale
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku

class MainActivity : FlutterActivity() {
    private val progressChannelId = "apkmesh_download_progress"
    private val eventChannelId = "apkmesh_download_events"
    private val notificationAction = "com.apkmesh.download_notification_action"
    private var notificationChannel: MethodChannel? = null
    private var notificationsReady = false
    private var pendingNotificationAction: Pair<String, String>? = null
    private val shizukuPermissionRequestCode = 7302
    private var pendingShizukuPermissionResult: MethodChannel.Result? = null
    private val shizukuPermissionListener =
        Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
            if (requestCode != shizukuPermissionRequestCode) return@OnRequestPermissionResultListener
            val pending = pendingShizukuPermissionResult ?: return@OnRequestPermissionResultListener
            pendingShizukuPermissionResult = null
            pending.success(
                if (grantResult == PackageManager.PERMISSION_GRANTED) {
                    "authorized"
                } else {
                    "denied"
                },
            )
        }
    private lateinit var languageContext: Context
    private val shizukuInstaller = lazy { ShizukuInstaller(applicationContext) { languageContext } }

    private fun updateAppLanguage(languageCode: String) {
        val locale = Locale(if (languageCode == "zh") "zh" else "en")
        val configuration = Configuration(resources.configuration).apply { setLocale(locale) }
        languageContext = createConfigurationContext(configuration)
        createNotificationChannels()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Shizuku.addRequestPermissionResultListener(shizukuPermissionListener)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        updateAppLanguage(Locale.getDefault().language)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.apkmesh/localization")
            .setMethodCallHandler { call, result ->
                if (call.method == "setLanguage") {
                    updateAppLanguage(call.argument<String>("languageCode") ?: "en")
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.apkmesh/install")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallPackages" -> {
                        val allowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                        result.success(allowed)
                    }
                    "requestInstallPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        }
                        result.success(null)
                    }
                    "shizukuStatus" -> result.success(shizukuStatus())
                    "requestShizukuPermission" -> requestShizukuPermission(result)
                    "installWithShizuku" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath.isNullOrBlank()) {
                            result.error(
                                "APK_FILE_INVALID",
                                languageContext.getString(R.string.apk_path_missing),
                                null,
                            )
                        } else {
                            shizukuInstaller.value.install(
                                filePath,
                                onSuccess = { result.success(true) },
                                onError = { code, message ->
                                    result.error(code, message, null)
                                },
                            )
                        }
                    }
                    "inspectInstall" -> inspectInstall(call, result)
                    "openInstalled" -> openInstalled(call, result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.apkmesh/external_download",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "launch" -> launchExternalDownloader(call, result)
                else -> result.notImplemented()
            }
        }

        val downloadChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.apkmesh/download_notifications",
        )
        notificationChannel = downloadChannel
        downloadChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "notificationsReady" -> {
                    notificationsReady = true
                    deliverPendingNotificationAction()
                    result.success(null)
                }
                "requestPermission" -> result.success(requestNotificationPermission())
                "showProgress" -> {
                    showDownloadProgress(call)
                    result.success(null)
                }
                "showPaused" -> {
                    showDownloadProgress(call, paused = true)
                    result.success(null)
                }
                "cancel" -> {
                    cancelDownloadNotification(call)
                    result.success(null)
                }
                "showCompleted" -> {
                    showDownloadCompleted(call)
                    result.success(null)
                }
                "showFailed" -> {
                    showDownloadFailed(call)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        handleNotificationAction(intent)
    }

    private fun launchExternalDownloader(call: MethodCall, result: MethodChannel.Result) {
        val rawUrl = call.argument<String>("url")
        val uri = rawUrl?.let(Uri::parse)
        if (uri == null || (uri.scheme != "http" && uri.scheme != "https")) {
            result.error("DOWNLOAD_URL_INVALID", languageContext.getString(R.string.download_url_invalid), null)
            return
        }

        val fileName = call.argument<String>("fileName")?.trim().orEmpty()
        val rawHeaders = call.argument<Map<*, *>>("headers").orEmpty()
        val headers = Bundle().apply {
            rawHeaders.forEach { (key, value) ->
                if (key is String && value is String) putString(key, value)
            }
        }
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/octet-stream")
            if (!headers.isEmpty) putExtra(Browser.EXTRA_HEADERS, headers)
            if (fileName.isNotEmpty()) {
                putExtra("title", fileName)
                putExtra("filename", fileName)
                putExtra("com.android.extra.filename", fileName)
            }
        }
        try {
            startActivity(Intent.createChooser(intent, languageContext.getString(R.string.choose_downloader)))
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    override fun onDestroy() {
        pendingShizukuPermissionResult?.let {
            it.error("SHIZUKU_ACTIVITY_DESTROYED", languageContext.getString(R.string.install_page_closed), null)
        }
        pendingShizukuPermissionResult = null
        Shizuku.removeRequestPermissionResultListener(shizukuPermissionListener)
        if (shizukuInstaller.isInitialized()) shizukuInstaller.value.dispose()
        super.onDestroy()
    }

    private fun shizukuStatus(): String = try {
        if (!Shizuku.pingBinder() || Shizuku.isPreV11()) {
            "unavailable"
        } else if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) {
            "authorized"
        } else {
            "denied"
        }
    } catch (_: RuntimeException) {
        "unavailable"
    }

    private fun requestShizukuPermission(result: MethodChannel.Result) {
        when (shizukuStatus()) {
            "authorized" -> result.success("authorized")
            "unavailable" -> result.success("unavailable")
            else -> {
                if (pendingShizukuPermissionResult != null) {
                    result.error(
                        "SHIZUKU_PERMISSION_PENDING",
                        languageContext.getString(R.string.shizuku_permission_pending),
                        null,
                    )
                    return
                }
                try {
                    pendingShizukuPermissionResult = result
                    Shizuku.requestPermission(shizukuPermissionRequestCode)
                } catch (error: RuntimeException) {
                    pendingShizukuPermissionResult = null
                    result.error(
                        "SHIZUKU_PERMISSION_REQUEST_FAILED",
                        error.message ?: languageContext.getString(R.string.shizuku_permission_failed),
                        null,
                    )
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun inspectInstall(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        if (filePath.isNullOrBlank()) {
            result.success(installInfoError(languageContext.getString(R.string.apk_path_missing)))
            return
        }
        val file = File(filePath)
        if (!file.isFile) {
            result.success(installInfoError(languageContext.getString(R.string.apk_not_found)))
            return
        }
        try {
            val archive = packageManager.getPackageArchiveInfo(filePath, 0)
            val packageName = archive?.packageName
            if (archive == null || packageName.isNullOrBlank()) {
                result.success(installInfoError(languageContext.getString(R.string.apk_info_failed)))
                return
            }
            val installed = try {
                packageManager.getPackageInfo(packageName, 0)
            } catch (_: PackageManager.NameNotFoundException) {
                null
            }
            val archiveVersionCode = packageVersionCode(archive)
            val installedVersionCode = installed?.let(::packageVersionCode)
            val versionMatches = installed != null &&
                archive.versionName == installed.versionName &&
                archiveVersionCode == installedVersionCode
            val canOpen = versionMatches &&
                packageManager.getLaunchIntentForPackage(packageName) != null
            result.success(
                mapOf(
                    "supported" to true,
                    "installed" to (installed != null),
                    "versionMatches" to versionMatches,
                    "canOpen" to canOpen,
                    "packageName" to packageName,
                    "archiveVersionName" to archive.versionName,
                    "archiveVersionCode" to archiveVersionCode,
                    "installedVersionName" to installed?.versionName,
                    "installedVersionCode" to installedVersionCode,
                ),
            )
        } catch (error: Exception) {
            result.success(installInfoError(error.message ?: languageContext.getString(R.string.install_status_failed)))
        }
    }

    @Suppress("DEPRECATION")
    private fun packageVersionCode(info: android.content.pm.PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }

    private fun installInfoError(message: String): Map<String, Any> = mapOf(
        "supported" to true,
        "installed" to false,
        "versionMatches" to false,
        "canOpen" to false,
        "error" to message,
    )

    private fun openInstalled(call: MethodCall, result: MethodChannel.Result) {
        val packageName = call.argument<String>("packageName")
        if (packageName.isNullOrBlank()) {
            result.success(false)
            return
        }
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent == null) {
                result.success(false)
                return
            }
            startActivity(launchIntent)
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationAction(intent)
    }

    private fun handleNotificationAction(intent: Intent?) {
        if (intent?.action != notificationAction) return
        val id = intent.getStringExtra("download_id") ?: return
        val action = intent.getStringExtra("download_action") ?: return
        if (action == "stop") {
            notificationManager().cancel(notificationId(id))
        }
        if (notificationsReady) {
            notificationChannel?.invokeMethod(
                "notificationAction",
                mapOf("id" to id, "action" to action),
            )
        } else {
            pendingNotificationAction = id to action
        }
    }

    private fun deliverPendingNotificationAction() {
        val pending = pendingNotificationAction ?: return
        pendingNotificationAction = null
        notificationChannel?.invokeMethod(
            "notificationAction",
            mapOf("id" to pending.first, "action" to pending.second),
        )
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                progressChannelId,
                languageContext.getString(R.string.download_progress),
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = languageContext.getString(R.string.download_progress_description) },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                eventChannelId,
                languageContext.getString(R.string.download_results),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = languageContext.getString(R.string.download_results_description) },
        )
    }

    private fun requestNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            return true
        }
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7301)
        return false
    }

    private fun canPostNotifications(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun showDownloadProgress(call: MethodCall, paused: Boolean = false) {
        if (!canPostNotifications()) return
        val id = call.argument<String>("id") ?: return
        val title = call.argument<String>("title") ?: languageContext.getString(R.string.apk_download)
        val received = call.argument<Number>("received")?.toLong() ?: 0L
        val total = call.argument<Number>("total")?.toLong()
        val text = if (total != null && total > 0) {
            val progress = "${formatBytes(received)} / ${formatBytes(total)}"
            if (paused) languageContext.getString(R.string.download_paused, progress) else progress
        } else {
            val progress = languageContext.getString(R.string.download_received, formatBytes(received))
            if (paused) languageContext.getString(R.string.download_paused, progress) else progress
        }
        val builder = notificationBuilder(progressChannelId)
            .setSmallIcon(
                if (paused) android.R.drawable.ic_media_pause
                else android.R.drawable.stat_sys_download,
            )
            .setContentTitle(title)
            .setContentText(text)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
        if (total != null && total > 0) {
            val percent = ((received.toDouble() / total.toDouble()) * 100)
                .toInt()
                .coerceIn(0, 100)
            builder.setProgress(100, percent, false)
        } else {
            builder.setProgress(0, 0, true)
        }
        launchPendingIntent()?.let(builder::setContentIntent)
        val nextAction = if (paused) "resume" else "pause"
        val nextLabel = if (paused) languageContext.getString(R.string.resume) else languageContext.getString(R.string.pause)
        builder.addAction(
            if (paused) android.R.drawable.ic_media_play
            else android.R.drawable.ic_media_pause,
            nextLabel,
            notificationActionPendingIntent(id, nextAction),
        )
        builder.addAction(
            android.R.drawable.ic_menu_close_clear_cancel,
            languageContext.getString(R.string.stop),
            notificationActionPendingIntent(id, "stop"),
        )
        notificationManager().notify(notificationId(id), builder.build())
    }

    private fun cancelDownloadNotification(call: MethodCall) {
        val id = call.argument<String>("id") ?: return
        notificationManager().cancel(notificationId(id))
    }

    private fun showDownloadCompleted(call: MethodCall) {
        if (!canPostNotifications()) return
        val id = call.argument<String>("id") ?: return
        val title = call.argument<String>("title") ?: languageContext.getString(R.string.apk_download)
        val builder = notificationBuilder(eventChannelId)
            .setSmallIcon(android.R.drawable.checkbox_on_background)
            .setContentTitle(title)
            .setContentText(languageContext.getString(R.string.ready_to_install))
            .setAutoCancel(true)
        launchPendingIntent()?.let(builder::setContentIntent)
        builder.addAction(
            android.R.drawable.ic_menu_view,
            languageContext.getString(R.string.install),
            notificationActionPendingIntent(id, "install"),
        )
        notificationManager().notify(notificationId(id), builder.build())
    }

    private fun showDownloadFailed(call: MethodCall) {
        if (!canPostNotifications()) return
        val id = call.argument<String>("id") ?: return
        val title = call.argument<String>("title") ?: languageContext.getString(R.string.apk_download)
        val error = call.argument<String>("error") ?: languageContext.getString(R.string.unknown_error)
        val builder = notificationBuilder(eventChannelId)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle(languageContext.getString(R.string.download_failed, title))
            .setContentText(error)
            .setStyle(Notification.BigTextStyle().bigText(error))
            .setAutoCancel(true)
        launchPendingIntent()?.let(builder::setContentIntent)
        notificationManager().notify(notificationId(id), builder.build())
    }

    private fun notificationBuilder(channelId: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            Notification.Builder(this)
        }

    private fun notificationActionPendingIntent(
        id: String,
        action: String,
    ): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            this.action = notificationAction
            putExtra("download_id", id)
            putExtra("download_action", action)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            this,
            notificationId("$id:$action"),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun launchPendingIntent(): PendingIntent? {
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(NotificationManager::class.java)

    private fun notificationId(id: String): Int = id.hashCode() and Int.MAX_VALUE

    private fun formatBytes(bytes: Long): String {
        if (bytes < 1024) return "$bytes B"
        val units = arrayOf("KB", "MB", "GB", "TB")
        var value = bytes.toDouble()
        var unit = -1
        while (value >= 1024 && unit < units.lastIndex) {
            value /= 1024
            unit += 1
        }
        return String.format(Locale.US, "%.1f %s", value, units[unit])
    }
}
