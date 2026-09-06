//
//  ImageActionsView.swift
//  ImportFrom
//
//  Created by Sherlock LUK on 31/07/2026.
//

import SwiftUI

struct ImageActionsView: View {
    
    private let onCopy: (() -> Void)?
    private let onSave: (() -> Void)?
    
    init(onCopy: (() -> Void)? = nil, onSave: (() -> Void)? = nil) {
        self.onCopy = onCopy
        self.onSave = onSave
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: {
                self.onCopy?()
            }) {
                Label("Copy", systemSymbol: .documentOnDocument)
            }

            Button(action: {
                self.onSave?()
            }) {
                Label("Save to Downloads", systemSymbol: .squareAndArrowDown)
            }
        }
        .padding(.top, 30)
    }
}
