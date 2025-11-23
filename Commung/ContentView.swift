//
//  ContentView.swift
//  Commung
//
//  Created by Jihyeok Seo on 11/16/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        if authViewModel.isLoading {
            VStack {
                ProgressView()
                Text(NSLocalizedString("loading.default", comment: ""))
                    .padding(.top)
            }
        } else {
            MainTabView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
