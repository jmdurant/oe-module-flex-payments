package com.example.flutter_flex

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class FlutterFlexPlugin: FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
  private lateinit var channel : MethodChannel
  private var activity: Activity? = null
  private var context: Context? = null
  private var pendingResult: MethodChannel.Result? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_flex")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
    when(call.method) {
      "init" -> {
        result.success(null)
      }
      "presentCheckout" -> {
        val act = activity ?: run {
          result.error("NO_ACTIVITY", "No activity", null); return
        }
        if (pendingResult != null) {
          result.error("IN_PROGRESS", "Another checkout in progress", null); return
        }
        val url = call.argument<String>("checkoutUrl") ?: run {
          result.error("ARG", "checkoutUrl required", null); return
        }
        val successContains = call.argument<String>("successUrlContains") ?: "status=success"
        val cancelContains = call.argument<String>("cancelUrlContains") ?: "status=cancel"
        pendingResult = result
        val intent = Intent(act, FlexWebViewActivity::class.java)
        intent.putExtra("checkoutUrl", url)
        intent.putExtra("successUrlContains", successContains)
        intent.putExtra("cancelUrlContains", cancelContains)
        act.startActivityForResult(intent, 9911)
      }
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addActivityResultListener(this)
  }
  override fun onDetachedFromActivityForConfigChanges() { activity = null }
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { onAttachedToActivity(binding) }
  override fun onDetachedFromActivity() { activity = null }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode != 9911) return false
    val res = pendingResult ?: return false
    pendingResult = null
    val map = HashMap<String, Any?>()
    map["status"] = data?.getStringExtra("status") ?: "cancel"
    map["sessionId"] = data?.getStringExtra("sessionId")
    res.success(map)
    return true
  }
}

