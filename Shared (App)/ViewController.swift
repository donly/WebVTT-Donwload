//
//  ViewController.swift
//  Shared (App)
//
//  Created by Tung Lim Chan on 8/6/2022.
//

import WebKit
import OSLog

#if os(iOS)
import UIKit
typealias PlatformViewController = UIViewController
#elseif os(macOS)
import Cocoa
import SafariServices
typealias PlatformViewController = NSViewController
#endif

let extensionBundleIdentifier = "com.propgm.WebVTTDownload.Extension"

class ViewController: PlatformViewController, WKNavigationDelegate, WKScriptMessageHandler {

    @IBOutlet var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.webView.navigationDelegate = self

#if os(iOS)
        self.webView.scrollView.isScrollEnabled = false
#endif

        self.webView.configuration.userContentController.add(self, name: "controller")

        self.webView.loadFileURL(Bundle.main.url(forResource: "Main", withExtension: "html")!, allowingReadAccessTo: Bundle.main.resourceURL!)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshState()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
#if os(macOS)
        guard let action = message.body as? String else { return }
        
        if action == "open-preferences" {
            SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier) { error in
                guard error == nil else {
                    // Insert code to inform the user that something went wrong.
                    return
                }
            }
        }
        else if action == "refresh-state" {
            self.refreshState()
        }
        
#endif
    }
    
    private func refreshState() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { (optionalState, optionalError) in
            if let error = optionalError {
                DispatchQueue.main.async {
                    self.signal(error: error)
                }
                return
            }
            
            let state = optionalState!

            let message = state.isEnabled
                ? NSLocalizedString("Extension is enabled.", comment: "Text indicating that the extension is enabled in Safari.")
                : NSLocalizedString("Extension is not enabled.", comment: "Text indicating that the extension is not enabled in Safari.")

            DispatchQueue.main.async {
                self.signal(message: message, isError: state.isEnabled)
            }
        }
    }
    
    private func signal(error: Error) {
        signal(message: error.localizedDescription, details: (error as NSError).helpAnchor, isError: true)
    }
    
    private func signal(message: String, details: String? = nil, isError: Bool = false) {
#if os(macOS)
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript("show('\(message)', \(isError))")
        }
#endif
    }
}
