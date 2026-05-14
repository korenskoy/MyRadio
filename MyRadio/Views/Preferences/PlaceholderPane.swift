//
//  PlaceholderPane.swift
//  MyRadio
//
//  Stand-in for Preferences sections that aren't built yet.
//

import SwiftUI

struct PlaceholderPane: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text("Coming soon")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
