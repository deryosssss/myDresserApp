//
//  LabeledTextField.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

struct LabeledTextField: View {
  let label: String
  @Binding var text: String

  var body: some View {
    HStack {
      Text(label)
        .font(AppFont.agdasima(size: 18))
        .frame(width: 140, alignment: .leading)
      TextField("", text: $text)
        .textFieldStyle(.roundedBorder)
    }
  }
}
