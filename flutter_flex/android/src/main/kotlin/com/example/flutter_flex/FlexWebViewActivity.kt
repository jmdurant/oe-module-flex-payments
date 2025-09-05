package com.example.flutter_flex

import android.app.Activity
import android.graphics.Bitmap
import android.os.Bundle
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.content.Intent

class FlexWebViewActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val webView = WebView(this)
    setContentView(webView)
    val url = intent.getStringExtra("checkoutUrl") ?: run { finishWith("error", null); return }
    val successContains = intent.getStringExtra("successUrlContains") ?: "status=success"
    val cancelContains = intent.getStringExtra("cancelUrlContains") ?: "status=cancel"

    webView.settings.javaScriptEnabled = true
    webView.webViewClient = object: WebViewClient() {
      override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
        val u = request?.url?.toString() ?: return false
        if (u.contains(successContains)) {
          finishWith("success", extractSessionId(u))
          return true
        }
        if (u.contains(cancelContains)) {
          finishWith("cancel", null)
          return true
        }
        return false
      }
      override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
        url?.let {
          if (it.contains(successContains)) { finishWith("success", extractSessionId(it)) }
          else if (it.contains(cancelContains)) { finishWith("cancel", null) }
        }
      }
    }
    webView.loadUrl(url)
  }

  private fun extractSessionId(url: String): String? {
    // naive extraction: look for session_id query param or 'id' param
    val uri = android.net.Uri.parse(url)
    return uri.getQueryParameter("session_id") ?: uri.getQueryParameter("id")
  }

  private fun finishWith(status: String, sessionId: String?) {
    val data = Intent()
    data.putExtra("status", status)
    if (sessionId != null) data.putExtra("sessionId", sessionId)
    setResult(RESULT_OK, data)
    finish()
  }
}

