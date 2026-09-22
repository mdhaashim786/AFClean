//
//  RootView.swift
//  AF Clean
//

import SwiftUI

struct RootView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("AF Clean")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    RootView()
}
