//
//  ContentView.swift
//  Taqvo
//
//  Created by Juan Oclock on 10/17/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.taqvoBackgroundDark)
    }
}

#Preview {
    ContentView()
}
