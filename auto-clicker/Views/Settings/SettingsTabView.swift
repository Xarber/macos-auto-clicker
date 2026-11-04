//
//  SettingsTabView.swift
//  auto-clicker
//
//  Created by Ben Tindall on 16/07/2022.
//

import SwiftUI

struct SettingsTabView<Content: View>: ContainerView {
    var content: () -> Content

    var body: some View {
        GroupBox {
            ScrollView {
                VStack(alignment: .leading, spacing: 6, content: self.content)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
