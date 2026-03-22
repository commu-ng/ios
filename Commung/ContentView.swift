import Observation
import SwiftUI
import UserNotifications
import WebKit

struct Tab: Identifiable, Equatable {
    let id: String
    let name: String
    let url: String
}

// MARK: - ContentView

struct ContentView: View {
    @State private var tabs: [Tab] = [
        Tab(id: "console", name: NSLocalizedString("nav.console", comment: ""), url: "https://commu.ng")
    ]
    @State private var selectedTabId = "console"
    @State private var manager = WebViewManager()
    @State private var showCopied = false

    var body: some View {
        MultiWebView(
            manager: manager,
            tabs: tabs,
            selectedTabId: selectedTabId,
            onCrossTabNavigation: { urlString in
                let tabId = findTabId(for: urlString)
                selectedTabId = tabId
                manager.navigate(tabId: tabId, to: urlString)
            },
            onLogout: {
                handleLogout()
            }
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            if !manager.currentURL.isEmpty {
                urlBar
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                if manager.communitiesFetched {
                    tabBar
                } else {
                    loginBar
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PushNotificationTapped"))) { notification in
            handleNotificationTap(notification.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PushTokenUpdated"))) { _ in
            guard let token = UserDefaults.standard.string(forKey: "pushToken") else { return }
            let js = "window.commungNative = { pushToken: '\(token)', platform: 'ios' };"
            for wv in manager.webViews.values {
                wv.evaluateJavaScript(js)
            }
        }
        .task {
            // Poll for login state by checking cookies — avoids evaluateJavaScript during navigation
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if !manager.communitiesFetched {
                    await fetchCommunitiesNatively()
                }
            }
        }
    }

    private func fetchCommunitiesNatively() async {
        // Read session cookie from WKWebsiteDataStore
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        guard let sessionCookie = cookies.first(where: { $0.name == "session_token" && $0.domain.hasSuffix("commu.ng") }) else {
            return
        }

        // Make native HTTP request with the cookie
        var request = URLRequest(url: URL(string: "https://api.commu.ng/console/communities/mine")!)
        request.setValue("session_token=\(sessionCookie.value)", forHTTPHeaderField: "Cookie")
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]],
              let communities = json["data"] else {
            return
        }

        let result = communities.compactMap { c -> (slug: String, name: String)? in
            guard let slug = c["slug"] as? String, let name = c["name"] as? String else { return nil }
            return (slug, name)
        }

        manager.communitiesFetched = true
        var newTabs = [tabs[0]]
        for (slug, name) in result {
            let communityUrl = "https://\(slug).commu.ng"
            let ssoUrl = "https://api.commu.ng/auth/sso?return_to=\(communityUrl)/"
            newTabs.append(Tab(id: slug, name: name, url: ssoUrl))
        }
        tabs = newTabs

        // Request push notification permission
        let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        if granted == true {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    private var homeURL: String {
        if selectedTabId == "console" {
            return "https://commu.ng"
        }
        return "https://\(selectedTabId).commu.ng"
    }

    private var urlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    manager.navigate(tabId: selectedTabId, to: homeURL)
                } label: {
                    Image(systemName: "house")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Button {
                    UIPasteboard.general.string = manager.currentURL
                    withAnimation(.easeInOut(duration: 0.15)) { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.15)) { showCopied = false }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: showCopied ? "checkmark" : "lock.fill")
                            .font(.system(size: showCopied ? 11 : 9, weight: showCopied ? .semibold : .regular))
                            .foregroundStyle(showCopied ? Color.green : Color(.tertiaryLabel))
                        Text(showCopied ? "Copied" : manager.currentURL)
                            .font(.system(size: 12, design: showCopied ? .default : .monospaced))
                            .fontWeight(showCopied ? .medium : .regular)
                            .foregroundStyle(showCopied ? Color.green : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentTransition(.interpolate)
                }

                if manager.isLoading {
                    Button {
                        manager.stopLoading(tabId: selectedTabId)
                    } label: {
                        ProgressView()
                            .controlSize(.small)
                    }
                } else {
                    Button {
                        manager.reload(tabId: selectedTabId)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            Divider()
        }
    }

    private var loginBar: some View {
        HStack {
            Button {
                manager.navigate(tabId: "console", to: "https://commu.ng/login")
            } label: {
                Label(NSLocalizedString("auth.login", comment: ""), systemImage: "person.crop.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tabs) { tab in
                    let isSelected = selectedTabId == tab.id
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTabId = tab.id
                        }
                    } label: {
                        Text(tab.name)
                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.accentColor.opacity(0.12) : Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func handleNotificationTap(_ userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
              let urlString = userInfo["url"] as? String else { return }

        let tabId = findTabId(for: urlString)
        selectedTabId = tabId
        manager.navigate(tabId: tabId, to: urlString)
    }

    private func handleLogout() {
        // Deregister push token
        if let token = UserDefaults.standard.string(forKey: "pushToken") {
            var request = URLRequest(url: URL(string: "https://api.commu.ng/console/devices/\(token)")!)
            request.httpMethod = "DELETE"
            URLSession.shared.dataTask(with: request).resume()
        }

        // Remove community webviews
        for tab in tabs where tab.id != "console" {
            if let wv = manager.webViews.removeValue(forKey: tab.id) {
                wv.removeFromSuperview()
            }
            manager.loadedTabs.remove(tab.id)
        }

        // Reset state — don't reload console, the web app already navigated to login
        manager.communitiesFetched = false
        tabs = [Tab(id: "console", name: NSLocalizedString("nav.console", comment: ""), url: "https://commu.ng")]
        selectedTabId = "console"
    }

    private func findTabId(for urlString: String) -> String {
        for tab in tabs where tab.id != "console" {
            if urlString.contains("\(tab.id).commu.ng") {
                return tab.id
            }
        }
        return "console"
    }
}

// MARK: - WebViewManager

@Observable
class WebViewManager {
    var webViews: [String: WKWebView] = [:]
    var loadedTabs: Set<String> = []
    var communitiesFetched = false
    var currentURL: String = ""
    var isLoading = false

    func navigate(tabId: String, to urlString: String) {
        guard let wv = webViews[tabId], let url = URL(string: urlString) else { return }
        loadedTabs.insert(tabId)
        wv.load(URLRequest(url: url))
    }

    func reload(tabId: String) {
        webViews[tabId]?.reload()
    }

    func stopLoading(tabId: String) {
        webViews[tabId]?.stopLoading()
    }
}

// MARK: - MultiWebView

struct MultiWebView: UIViewRepresentable {
    let manager: WebViewManager
    let tabs: [Tab]
    let selectedTabId: String
    var onCrossTabNavigation: ((String) -> Void)?
    var onLogout: (() -> Void)?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ container: UIView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onCrossTabNavigation = onCrossTabNavigation
        coordinator.onLogout = onLogout

        for tab in tabs {
            let wv: WKWebView
            if let existing = manager.webViews[tab.id] {
                wv = existing
            } else {
                wv = WKWebView(frame: container.bounds)
                wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                wv.allowsBackForwardNavigationGestures = true
                wv.navigationDelegate = coordinator
                wv.isOpaque = false
                wv.backgroundColor = .systemBackground
                wv.scrollView.backgroundColor = .systemBackground
                let refreshControl = UIRefreshControl()
                refreshControl.addTarget(coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
                wv.scrollView.refreshControl = refreshControl
                container.addSubview(wv)
                manager.webViews[tab.id] = wv
                coordinator.observeURL(for: tab.id, webView: wv)
            }

            wv.isHidden = tab.id != selectedTabId

            if tab.id == selectedTabId {
                manager.currentURL = wv.url?.absoluteString ?? ""
                manager.isLoading = wv.isLoading
            }

            if tab.id == selectedTabId && !manager.loadedTabs.contains(tab.id) {
                manager.loadedTabs.insert(tab.id)
                if let url = URL(string: tab.url) {
                    wv.load(URLRequest(url: url))
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let manager: WebViewManager
        var onCrossTabNavigation: ((String) -> Void)?
        var onLogout: (() -> Void)?
        private var urlObservations: [String: NSKeyValueObservation] = [:]
        private var isCheckingLogout = false

        init(manager: WebViewManager) {
            self.manager = manager
        }

        func observeURL(for tabId: String, webView: WKWebView) {
            urlObservations[tabId] = webView.observe(\.url, options: .new) { [weak self] wv, _ in
                guard let self, !wv.isHidden else { return }
                DispatchQueue.main.async {
                    self.manager.currentURL = wv.url?.absoluteString ?? ""
                }
                if tabId == "console" {
                    if self.manager.communitiesFetched {
                        self.checkForLogout()
                    }
                }
            }
        }

        private func checkForLogout() {
            guard !isCheckingLogout else { return }
            isCheckingLogout = true
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self else { return }
                self.isCheckingLogout = false
                let hasSession = cookies.contains { cookie in
                    cookie.name == "session_token" && cookie.domain.hasSuffix("commu.ng")
                }
                if !hasSession {
                    DispatchQueue.main.async {
                        self.onLogout?()
                    }
                }
            }
        }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            guard let webView = sender.superview?.superview as? WKWebView else {
                sender.endRefreshing()
                return
            }
            webView.reload()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if !webView.isHidden {
                manager.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.refreshControl?.endRefreshing()
            if !webView.isHidden {
                manager.isLoading = false
            }
            if let token = UserDefaults.standard.string(forKey: "pushToken") {
                webView.evaluateJavaScript("window.commungNative = { pushToken: '\(token)', platform: 'ios' };")
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            webView.scrollView.refreshControl?.endRefreshing()
            manager.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            webView.scrollView.refreshControl?.endRefreshing()
            manager.isLoading = false
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, let host = url.host else {
                decisionHandler(.allow)
                return
            }

            // External links → Safari
            if !host.hasSuffix("commu.ng") {
                if navigationAction.navigationType == .linkActivated {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
                decisionHandler(.allow)
                return
            }

            // Cross-subdomain link (e.g. console linking to slug.commu.ng) → open in appropriate tab
            if navigationAction.navigationType == .linkActivated {
                let currentHost = webView.url?.host ?? ""
                if host != currentHost && host != "api.commu.ng" {
                    onCrossTabNavigation?(url.absoluteString)
                    decisionHandler(.cancel)
                    return
                }
            }

            decisionHandler(.allow)
        }
    }
}

