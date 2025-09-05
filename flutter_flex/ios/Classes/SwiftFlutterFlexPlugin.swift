import Flutter
import UIKit
import WebKit

public class SwiftFlutterFlexPlugin: NSObject, FlutterPlugin {
  var result: FlutterResult?
  var controller: UIViewController?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_flex", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterFlexPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "init":
      result(nil)
    case "presentCheckout":
      guard let args = call.arguments as? [String: Any],
            let urlStr = args["checkoutUrl"] as? String,
            let url = URL(string: urlStr) else {
        result(FlutterError(code: "ARG", message: "checkoutUrl required", details: nil)); return
      }
      let successContains = (args["successUrlContains"] as? String) ?? "status=success"
      let cancelContains = (args["cancelUrlContains"] as? String) ?? "status=cancel"
      self.result = result
      presentWeb(url: url, successContains: successContains, cancelContains: cancelContains)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func presentWeb(url: URL, successContains: String, cancelContains: String) {
    guard let root = UIApplication.shared.keyWindow?.rootViewController else { self.finish(status: "error", sessionId: nil); return }
    let web = WKWebView()
    web.navigationDelegate = self
    let vc = UIViewController()
    vc.view = web
    self.controller = vc
    root.present(vc, animated: true)
    web.load(URLRequest(url: url))
    web.tag = 0
    objc_setAssociatedObject(web, &AssociatedKeys.successKey, successContains, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    objc_setAssociatedObject(web, &AssociatedKeys.cancelKey, cancelContains, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
  }

  private func finish(status: String, sessionId: String?) {
    controller?.dismiss(animated: true)
    if let res = self.result {
      var map: [String: Any?] = ["status": status]
      if let sid = sessionId { map["sessionId"] = sid }
      res(map)
    }
    self.result = nil
    self.controller = nil
  }
}

private struct AssociatedKeys {
  static var successKey = "successKey"
  static var cancelKey = "cancelKey"
}

extension SwiftFlutterFlexPlugin: WKNavigationDelegate {
  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if let url = navigationAction.request.url?.absoluteString,
       let success = objc_getAssociatedObject(webView, &AssociatedKeys.successKey) as? String,
       let cancel = objc_getAssociatedObject(webView, &AssociatedKeys.cancelKey) as? String {
      if url.contains(success) {
        decisionHandler(.cancel)
        finish(status: "success", sessionId: extractSessionId(url: url))
        return
      }
      if url.contains(cancel) {
        decisionHandler(.cancel)
        finish(status: "cancel", sessionId: nil)
        return
      }
    }
    decisionHandler(.allow)
  }

  private func extractSessionId(url: String) -> String? {
    if let comps = URLComponents(string: url) {
      return comps.queryItems?.first(where: { $0.name == "session_id" })?.value ??
             comps.queryItems?.first(where: { $0.name == "id" })?.value
    }
    return nil
  }
}

