//
//  ActionStageLine.swift
//  auto-clicker
//
//  Created by Ben Tindall on 27/03/2022.
//

import SwiftUI
import Defaults

struct ActionStageLine<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @Default(.appearanceSelectedTheme) private var activeTheme

    var body: some View {
        HStack {
            HStack(content: content)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(self.activeTheme.fontColour)
                .padding(.vertical, 2)

            Spacer()
        }
    }
}

//struct ActionStageLine_Previews: PreviewProvider {
//    static var previews: some View {
//        ActionStageLine {
//
//        }
//    }
//}
