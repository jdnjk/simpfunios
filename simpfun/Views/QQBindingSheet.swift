//
//  QQBindingSheet.swift
//  simpfun
//

import SwiftUI

struct QQBindingSheet: View {
    let currentQQ: Int?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    init(currentQQ: Int? = nil) {
        self.currentQQ = currentQQ
    }

    @State private var qq = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isQQFieldFocused: Bool

    private var trimmedQQ: String {
        qq.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValidQQ: Bool {
        (5...12).contains(trimmedQQ.count) && trimmedQQ.allSatisfy(\.isNumber)
    }

    private var canSubmit: Bool {
        isValidQQ && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(currentQQ == nil ? "请输入 QQ 号" : "请输入新的 QQ 号", text: $qq)
                        .keyboardType(.numberPad)
                        .focused($isQQFieldFocused)
                } header: {
                    Text("QQ 号")
                } footer: {
                    if let currentQQ {
                        Text(verbatim: "当前绑定：\(currentQQ)。保存后将替换为新 QQ。")
                    } else {
                        Text("绑定后可使用 QQ 接收通知。")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(currentQQ == nil ? "绑定 QQ" : "换绑 QQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await bind() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text(currentQQ == nil ? "绑定" : "保存")
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .task {
                isQQFieldFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    private func bind() async {
        guard canSubmit else { return }

        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await model.bindQQ(trimmedQQ)
            dismiss()
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    QQBindingSheet()
        .environment(AppModel())
}
