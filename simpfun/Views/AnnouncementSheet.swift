//
//  AnnouncementSheet.swift
//  simpfun
//

import SwiftUI

struct AnnouncementSheet: View {
    let announcement: Announcement

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(announcement.title)
                        .font(.headline)

                    Text(announcement.renderedText)
                        .font(.body)
                        .tint(Color.accentColor)
                        .textSelection(.enabled)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("公告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await markRead() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("已阅")
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func markRead() async {
        guard !isSubmitting else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await model.markAnnouncementsRead()
            dismiss()
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
