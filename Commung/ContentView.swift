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
        .onAppear {
            manager.onLogin = { communities in
                var newTabs = [tabs[0]]
                for (slug, name) in communities {
                    let communityUrl = "https://\(slug).commu.ng"
                    let ssoUrl = "https://api.commu.ng/auth/sso?return_to=\(communityUrl)/"
                    newTabs.append(Tab(id: slug, name: name, url: ssoUrl))
                }
                tabs = newTabs
            }
            manager.onLogoutDetected = {
                handleLogout()
            }
            manager.startCookieObserver()
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
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                guard let sessionCookie = cookies.first(where: { $0.name == "session_token" && $0.domain.hasSuffix("commu.ng") }) else { return }
                var request = URLRequest(url: URL(string: "https://api.commu.ng/console/devices/\(token)")!)
                request.httpMethod = "DELETE"
                request.setValue("session_token=\(sessionCookie.value)", forHTTPHeaderField: "Cookie")
                URLSession.shared.dataTask(with: request).resume()
            }
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
class WebViewManager: NSObject, WKHTTPCookieStoreObserver {
    var webViews: [String: WKWebView] = [:]
    var loadedTabs: Set<String> = []
    var communitiesFetched = false
    var currentURL: String = ""
    var isLoading = false

    var onLogin: ([(slug: String, name: String)]) -> Void = { _ in }
    var onLogoutDetected: () -> Void = {}

    private var isFetchingCommunities = false

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

    func startCookieObserver() {
        WKWebsiteDataStore.default().httpCookieStore.add(self)
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }
            let hasSession = cookies.contains { $0.name == "session_token" && $0.domain.hasSuffix("commu.ng") }

            DispatchQueue.main.async {
                if hasSession && !self.communitiesFetched && !self.isFetchingCommunities {
                    // Session cookie appeared — user logged in
                    self.fetchCommunities(cookies: cookies)
                } else if !hasSession && self.communitiesFetched {
                    // Session cookie gone — user logged out
                    self.onLogoutDetected()
                }
            }
        }
    }

    private func registerPushTokenWhenReady(sessionCookieValue: String) {
        Task {
            // Poll for the push token (set by AppDelegate after APNs responds)
            for _ in 0..<10 {
                try? await Task.sleep(for: .seconds(1))
                if let token = UserDefaults.standard.string(forKey: "pushToken") {
                    await registerDevice(pushToken: token, sessionCookieValue: sessionCookieValue)
                    return
                }
            }
        }
    }

    private func registerDevice(pushToken: String, sessionCookieValue: String) async {
        var request = URLRequest(url: URL(string: "https://api.commu.ng/console/devices")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("session_token=\(sessionCookieValue)", forHTTPHeaderField: "Cookie")

        let deviceModel = await MainActor.run { UIDevice.current.model }
        let osVersion = await MainActor.run { "iOS \(UIDevice.current.systemVersion)" }
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

        let body: [String: String] = [
            "push_token": pushToken,
            "platform": "ios",
            "device_model": deviceModel,
            "os_version": osVersion,
            "app_version": appVersion ?? "",
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }

    private func fetchCommunities(cookies: [HTTPCookie]) {
        guard let sessionCookie = cookies.first(where: { $0.name == "session_token" && $0.domain.hasSuffix("commu.ng") }) else { return }
        isFetchingCommunities = true

        Task {
            var request = URLRequest(url: URL(string: "https://api.commu.ng/console/communities/mine")!)
            request.setValue("session_token=\(sessionCookie.value)", forHTTPHeaderField: "Cookie")
            request.timeoutInterval = 10

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]],
                  let communities = json["data"] else {
                await MainActor.run { self.isFetchingCommunities = false }
                return
            }

            let result = communities.compactMap { c -> (slug: String, name: String)? in
                guard let slug = c["slug"] as? String, let name = c["name"] as? String else { return nil }
                return (slug, name)
            }

            await MainActor.run {
                self.isFetchingCommunities = false
                self.communitiesFetched = true
                self.onLogin(result)
            }

            // Request push notification permission and register device
            let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted == true {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                // Wait for token to arrive, then register natively
                self.registerPushTokenWhenReady(sessionCookieValue: sessionCookie.value)
            }
        }
    }
}

// MARK: - MultiWebView

struct MultiWebView: UIViewRepresentable {
    let manager: WebViewManager
    let tabs: [Tab]
    let selectedTabId: String
    var onCrossTabNavigation: ((String) -> Void)?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .systemBackground
        return view
    }

    func updateUIView(_ container: UIView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onCrossTabNavigation = onCrossTabNavigation

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
        private var urlObservations: [String: NSKeyValueObservation] = [:]

        init(manager: WebViewManager) {
            self.manager = manager
        }

        func observeURL(for tabId: String, webView: WKWebView) {
            urlObservations[tabId] = webView.observe(\.url, options: .new) { [weak self] wv, _ in
                guard let self, !wv.isHidden else { return }
                DispatchQueue.main.async {
                    self.manager.currentURL = wv.url?.absoluteString ?? ""
                }
            }
        }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            var view: UIView? = sender
            while let current = view {
                if let webView = current as? WKWebView {
                    webView.reload()
                    return
                }
                view = current.superview
            }
            sender.endRefreshing()
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
            // Trigger cookie check after page load as fallback
            // (cookiesDidChange may not fire for httpOnly Set-Cookie headers)
            if !manager.communitiesFetched, manager.webViews["console"] === webView {
                manager.cookiesDidChange(in: WKWebsiteDataStore.default().httpCookieStore)
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

