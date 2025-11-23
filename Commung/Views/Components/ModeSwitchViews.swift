import SwiftUI

// View that switches to Console mode when appearing
struct ConsoleModeSwitch: View {
    @EnvironmentObject var appModeContext: AppModeContext

    var body: some View {
        Color.clear
            .onAppear {
                appModeContext.switchTo(.console)
            }
    }
}

// View that switches to App mode when appearing
struct AppModeSwitch: View {
    @EnvironmentObject var appModeContext: AppModeContext

    var body: some View {
        Color.clear
            .onAppear {
                appModeContext.switchTo(.app)
            }
    }
}
