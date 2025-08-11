package com.mjnaz.fi.ae.update_app 

import android.app.Activity
import android.app.Activity.RESULT_CANCELED
import android.app.Activity.RESULT_OK
import android.app.Application
import android.content.Intent
import android.content.IntentSender.SendIntentException
import android.os.Bundle
import android.util.Log
import com.google.android.play.core.appupdate.*
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

interface ActivityProvider {
    fun addActivityResultListener(callback: PluginRegistry.ActivityResultListener)
    fun activity(): Activity
}

class UpdateAppPlugin : FlutterPlugin, 
MethodChannel.MethodCallHandler,
PluginRegistry.ActivityResultListener, 
Application.ActivityLifecycleCallbacks,
ActivityAware, 
EventChannel.StreamHandler 
{

    companion object {
        private const val TAG = "UpdateAppPlugin"
        private const val REQUEST_CODE_START_UPDATE = 1276
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var installStateSink: EventChannel.EventSink? = null

    private var appUpdateManager: AppUpdateManager? = null
    private var appUpdateInfo: AppUpdateInfo? = null
    private var appUpdateType: Int? = null
    private var updateResult: MethodChannel.Result? = null

    private var activityProvider: ActivityProvider? = null

    private lateinit var installStateUpdatedListener: InstallStateUpdatedListener

    // --- Stream Handler ---
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        installStateSink = events
    }

    override fun onCancel(arguments: Any?) {
        installStateSink = null
    }

    private fun emitInstallState(status: Int) {
        installStateSink?.success(status)
    }

    // --- Plugin Lifecycle ---
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "update_app/methods")
        eventChannel = EventChannel(binding.binaryMessenger, "update_app/stateEvents")

        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)

        installStateUpdatedListener = InstallStateUpdatedListener { state ->
            emitInstallState(state.installStatus())
        }

        appUpdateManager?.registerListener(installStateUpdatedListener)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        appUpdateManager?.unregisterListener(installStateUpdatedListener)
    }

    // --- Method Call Handler ---
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkForUpdate" -> checkForUpdate(result)
            "performImmediateUpdate" -> performImmediateUpdate(result)
            "startFlexibleUpdate" -> startFlexibleUpdate(result)
            "completeFlexibleUpdate" -> completeFlexibleUpdate(result)
            else -> result.notImplemented()
        }
    }

    // --- Activity Results ---
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_START_UPDATE) return false

        when (appUpdateType) {
            AppUpdateType.IMMEDIATE -> handleImmediateResult(resultCode)
            AppUpdateType.FLEXIBLE -> handleFlexibleResult(resultCode)
        }

        return true
    }

    private fun handleImmediateResult(resultCode: Int) {
        when (resultCode) {
            RESULT_OK -> updateResult?.success(null)
            RESULT_CANCELED -> updateResult?.error("USER_DENIED_UPDATE", resultCode.toString(), null)
            ActivityResult.RESULT_IN_APP_UPDATE_FAILED -> updateResult?.error("IN_APP_UPDATE_FAILED", "Update failed", null)
        }
        updateResult = null
    }

    private fun handleFlexibleResult(resultCode: Int) {
        when (resultCode) {
            RESULT_CANCELED -> updateResult?.error("USER_DENIED_UPDATE", resultCode.toString(), null)
            ActivityResult.RESULT_IN_APP_UPDATE_FAILED -> updateResult?.error("IN_APP_UPDATE_FAILED", resultCode.toString(), null)
        }
        updateResult = null
    }

    // --- Flutter Activity Lifecycle ---
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityProvider = object : ActivityProvider {
            override fun addActivityResultListener(callback: PluginRegistry.ActivityResultListener) {
                binding.addActivityResultListener(callback)
            }

            override fun activity(): Activity = binding.activity
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityProvider = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityProvider = null
    }

    // --- Android App Lifecycle (Optional) ---
    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
    override fun onActivityStarted(activity: Activity) {}
    override fun onActivityResumed(activity: Activity) {
        val activityInstance = activityProvider?.activity() ?: return
        appUpdateManager?.appUpdateInfo?.addOnSuccessListener { info ->
            if (info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS &&
                appUpdateType == AppUpdateType.IMMEDIATE
            ) {
                try {
                    appUpdateManager?.startUpdateFlow(
                        info,
                        activityInstance,
                        AppUpdateOptions.defaultOptions(AppUpdateType.IMMEDIATE)
                    )
                } catch (e: SendIntentException) {
                    Log.e(TAG, "Could not start update flow", e)
                }
            }
        }
    }

    override fun onActivityPaused(activity: Activity) {}
    override fun onActivityStopped(activity: Activity) {}
    override fun onActivityDestroyed(activity: Activity) {}
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

    // --- Update Logic ---
    private fun checkForUpdate(result: MethodChannel.Result) {
        val activity = activityProvider?.activity()
        if (activity == null) {
            result.error("REQUIRE_FOREGROUND_ACTIVITY", "Plugin requires a foreground activity", null)
            return
        }

        activityProvider?.addActivityResultListener(this)
        activity.application.registerActivityLifecycleCallbacks(this)
        appUpdateManager = AppUpdateManagerFactory.create(activity)

        appUpdateManager?.appUpdateInfo?.addOnSuccessListener { info ->
            appUpdateInfo = info
            result.success(
                mapOf(
                    "updateAvailability" to info.updateAvailability(),
                    "immediateAllowed" to info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
                    "immediateAllowedPreconditions" to info.getFailedUpdatePreconditions(AppUpdateOptions.defaultOptions(AppUpdateType.IMMEDIATE)).map { it.toInt() },
                    "flexibleAllowed" to info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
                    "flexibleAllowedPreconditions" to info.getFailedUpdatePreconditions(AppUpdateOptions.defaultOptions(AppUpdateType.FLEXIBLE)).map { it.toInt() },
                    "availableVersionCode" to info.availableVersionCode(),
                    "installStatus" to info.installStatus(),
                    "packageName" to info.packageName(),
                    "clientVersionStalenessDays" to info.clientVersionStalenessDays(),
                    "updatePriority" to info.updatePriority()
                )
            )
        }?.addOnFailureListener {
            result.error("TASK_FAILURE", it.message, null)
        }
    }

    private fun performImmediateUpdate(result: MethodChannel.Result) {
        checkAppState(result) {
            appUpdateType = AppUpdateType.IMMEDIATE
            updateResult = result
            startUpdateFlow(AppUpdateType.IMMEDIATE)
        }
    }

    private fun startFlexibleUpdate(result: MethodChannel.Result) {
        checkAppState(result) {
            appUpdateType = AppUpdateType.FLEXIBLE
            updateResult = result
            startUpdateFlow(AppUpdateType.FLEXIBLE)

            appUpdateManager?.registerListener { state ->
                emitInstallState(state.installStatus())
                when (state.installStatus()) {
                    InstallStatus.DOWNLOADED -> {
                        updateResult?.success(null)
                        updateResult = null
                    }
                    else -> {
                        if (state.installErrorCode() != InstallErrorCode.NO_ERROR) {
                            updateResult?.error("INSTALL_ERROR", state.installErrorCode().toString(), null)
                            updateResult = null
                        }
                    }
                }
            }
        }
    }

    private fun completeFlexibleUpdate(result: MethodChannel.Result) {
        checkAppState(result) {
            appUpdateManager?.completeUpdate()
            result.success(null)
        }
    }

    // --- Utilities ---
    private fun checkAppState(result: MethodChannel.Result, action: () -> Unit) {
        when {
            appUpdateInfo == null -> result.error("REQUIRE_CHECK_FOR_UPDATE", "Call checkForUpdate first!", null)
            appUpdateManager == null -> result.error("REQUIRE_CHECK_FOR_UPDATE", "AppUpdateManager not initialized", null)
            activityProvider?.activity() == null -> result.error("REQUIRE_FOREGROUND_ACTIVITY", "Requires a foreground activity", null)
            else -> action()
        }
    }

    private fun startUpdateFlow(updateType: Int) {
        try {
            appUpdateManager?.startUpdateFlow(
                appUpdateInfo!!,
                activityProvider!!.activity(),
                AppUpdateOptions.defaultOptions(updateType)
            )
        } catch (e: SendIntentException) {
            Log.e(TAG, "Failed to start update flow", e)
            updateResult?.error("UPDATE_FLOW_FAILED", e.message, null)
        }
    }
}
