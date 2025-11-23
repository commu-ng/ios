import SwiftUI

struct ModeToggleButton: View {
    @EnvironmentObject var appModeContext: AppModeContext

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appModeContext.toggleMode()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: appModeContext.currentMode == .app ? "gearshape" : "person.3")
                    .font(.subheadline)
            }
        }
        .accessibilityLabel(appModeContext.currentMode == .app ? "Switch to Console Mode" : "Switch to App Mode")
    }
}

struct ModeToggleButtonExpanded: View {
    @EnvironmentObject var appModeContext: AppModeContext

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appModeContext.toggleMode()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: appModeContext.currentMode == .app ? "gearshape" : "person.3")
                    .font(.subheadline)
                Text(appModeContext.currentMode == .app ? "Console" : "App")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
        .accessibilityLabel(appModeContext.currentMode == .app ? "Switch to Console Mode" : "Switch to App Mode")
    }
}

#Preview {
    VStack(spacing: 20) {
        ModeToggleButton()
        ModeToggleButtonExpanded()
    }
    .environmentObject(AppModeContext())
}
