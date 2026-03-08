//
//  SplashView.swift
//  KnowEat
//
//  Created by Lisette HG on 25/02/26.
//

import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            Image("KnowEat Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(rotation))
                .opacity(opacity)
                .accessibilityHidden(true)
        }
        .onAppear {
            if reduceMotion {
                opacity = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onFinished() }
            } else {
                withAnimation(.easeIn(duration: 0.6).delay(0.3)) { rotation = 360 }
                withAnimation(.easeOut(duration: 0.3).delay(0.8)) { opacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { onFinished() }
            }
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
