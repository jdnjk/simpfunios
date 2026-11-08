//
//  LoginViewModel.swift
//  simpfun
//

import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {
    var username = ""
    var password = ""
    private(set) var isSubmitting = false
    private(set) var cooldownRemaining = 0
    var errorMessage: String?

    private var cooldownTask: Task<Void, Never>?

    var isLoginEnabled: Bool {
        !isSubmitting
            && cooldownRemaining == 0
            && !trimmedUsername.isEmpty
            && !password.isEmpty
    }

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func submit(using model: AppModel) async {
        guard isLoginEnabled else { return }

        errorMessage = nil
        isSubmitting = true
        startCooldown()
        defer { isSubmitting = false }

        do {
            try await model.login(username: trimmedUsername, password: password)
            password = ""
        } catch let error as APIError {
            if let message = model.handleLoginError(error) {
                errorMessage = message
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 登录按钮按下后冷却 3 秒，期间不可再次提交。
    private func startCooldown() {
        cooldownTask?.cancel()
        cooldownRemaining = 3

        cooldownTask = Task { [weak self] in
            for _ in 0..<3 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.cooldownRemaining = max(0, self.cooldownRemaining - 1)
            }
        }
    }
}
