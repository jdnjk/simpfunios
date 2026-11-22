//
//  CodeEditorView.swift
//  simpfun
//
//  基于 Runestone（Tree-sitter）的代码编辑区。
//

import Observation
import Runestone
import SwiftUI
import UIKit

/// 让 SwiftUI 侧可以命令式地操作底层编辑器（撤销、定位、替换等）。
@Observable
final class EditorController {
    weak var textView: TextView?

    private(set) var canUndo = false
    private(set) var canRedo = false

    func attach(_ textView: TextView) {
        self.textView = textView
        refreshUndoState()
    }

    func refreshUndoState() {
        let manager = textView?.undoManager
        let undo = manager?.canUndo ?? false
        let redo = manager?.canRedo ?? false
        if undo != canUndo { canUndo = undo }
        if redo != canRedo { canRedo = redo }
    }

    func undo() {
        textView?.undoManager?.undo()
        refreshUndoState()
    }

    func redo() {
        textView?.undoManager?.redo()
        refreshUndoState()
    }

    func select(_ range: NSRange) {
        guard let textView else { return }
        let length = (textView.text as NSString).length
        guard range.location != NSNotFound, range.location <= length else { return }
        let clamped = NSRange(location: range.location, length: min(range.length, length - range.location))
        textView.selectedRange = clamped
        textView.scrollRangeToVisible(clamped)
    }

    /// 用编辑器自身的 `replace` 改文本，这样系统撤销栈里会留下记录。
    func replace(range: NSRange, with text: String) {
        guard let textView else { return }
        let length = (textView.text as NSString).length
        guard range.location + range.length <= length else { return }
        textView.replace(range, withText: text)
    }

    func replaceAll(with text: String) {
        guard let textView else { return }
        let length = (textView.text as NSString).length
        textView.replace(NSRange(location: 0, length: length), withText: text)
    }

    /// 第 `line` 行（从 1 开始）的范围，用于「转到指定行」。
    func rangeOfLine(_ line: Int, in text: String) -> NSRange? {
        let ns = text as NSString
        guard line > 0, ns.length >= 0 else { return nil }

        var current = 1
        var location = 0
        while location <= ns.length {
            let range = ns.lineRange(for: NSRange(location: location, length: 0))
            if current == line {
                let contentLength = range.length
                return NSRange(location: range.location, length: max(0, contentLength - 1))
            }
            let next = range.location + range.length
            if next <= location { break }
            location = next
            current += 1
        }
        return nil
    }

    /// 行列号（都从 1 开始）。
    static func lineAndColumn(at location: Int, in text: String) -> (line: Int, column: Int) {
        let ns = text as NSString
        let clamped = min(max(0, location), ns.length)

        var line = 1
        var lineStart = 0
        var index = 0
        while index < clamped {
            let range = ns.lineRange(for: NSRange(location: index, length: 0))
            let next = range.location + range.length
            if next <= index || next > clamped { break }
            line += 1
            lineStart = next
            index = next
        }
        return (line, clamped - lineStart + 1)
    }
}

/// 代码编辑区：Runestone 的 `TextView` + Tree-sitter 语法高亮 + 查找匹配底色。
struct CodeEditorView: UIViewRepresentable {
    @Binding var text: String
    var language: SyntaxLanguage
    var isLineWrappingEnabled: Bool
    var matches: [NSRange]
    var currentMatch: NSRange?
    var controller: EditorController
    var onSelectionChange: (NSRange) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> TextView {
        let textView = TextView()
        textView.editorDelegate = context.coordinator
        textView.theme = EditorTheme.shared
        textView.backgroundColor = .systemBackground
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 6, bottom: 32, right: 16)
        textView.showLineNumbers = true
        textView.isLineWrappingEnabled = isLineWrappingEnabled
        textView.indentStrategy = .space(length: 4)
        textView.insertionPointColor = .tintColor
        textView.selectionHighlightColor = UIColor.tintColor.withAlphaComponent(0.25)

        context.coordinator.applyState(text: text, language: language, to: textView)
        controller.attach(textView)
        return textView
    }

    func updateUIView(_ textView: TextView, context: Context) {
        context.coordinator.parent = self

        if textView.text != text {
            context.coordinator.applyState(text: text, language: language, to: textView)
        } else if context.coordinator.language != language {
            context.coordinator.applyLanguage(language, to: textView)
        }

        if textView.isLineWrappingEnabled != isLineWrappingEnabled {
            textView.isLineWrappingEnabled = isLineWrappingEnabled
        }

        context.coordinator.applyHighlights(
            matches: matches,
            current: currentMatch,
            to: textView
        )
    }

    final class Coordinator: NSObject, TextViewDelegate {
        var parent: CodeEditorView
        private(set) var language: SyntaxLanguage

        private var highlightedMatches: [NSRange] = []
        private var highlightedCurrent: NSRange?

        init(parent: CodeEditorView) {
            self.parent = parent
            self.language = parent.language
        }

        // MARK: 文本状态

        func applyState(text: String, language: SyntaxLanguage, to textView: TextView) {
            self.language = language
            textView.setState(makeState(text: text, language: language))
            applyHighlights(matches: parent.matches, current: parent.currentMatch, to: textView)
        }

        private func makeState(text: String, language: SyntaxLanguage) -> TextViewState {
            if let treeSitter = language.treeSitterLanguage {
                return TextViewState(text: text, theme: EditorTheme.shared, language: treeSitter)
            }
            return TextViewState(text: text, theme: EditorTheme.shared)
        }

        func applyLanguage(_ language: SyntaxLanguage, to textView: TextView) {
            self.language = language
            if let treeSitter = language.treeSitterLanguage {
                textView.setLanguageMode(TreeSitterLanguageMode(language: treeSitter))
            } else {
                textView.setLanguageMode(PlainTextLanguageMode())
            }
        }

        // MARK: 查找高亮

        func applyHighlights(matches: [NSRange], current: NSRange?, to textView: TextView) {
            guard matches != highlightedMatches || current != highlightedCurrent else { return }
            highlightedMatches = matches
            highlightedCurrent = current

            let length = (textView.text as NSString).length
            var ranges: [HighlightedRange] = []
            ranges.reserveCapacity(matches.count)

            for (index, range) in matches.enumerated() {
                guard range.location != NSNotFound,
                      range.location + range.length <= length else { continue }
                let isCurrent = range == current
                ranges.append(
                    HighlightedRange(
                        id: "match-\(index)",
                        range: range,
                        color: isCurrent
                            ? UIColor.systemOrange.withAlphaComponent(0.55)
                            : UIColor.systemYellow.withAlphaComponent(0.28),
                        cornerRadius: 2
                    )
                )
            }

            textView.highlightedRanges = ranges
        }

        // MARK: TextViewDelegate

        func textViewDidChange(_ textView: TextView) {
            parent.text = textView.text
            parent.controller.refreshUndoState()
        }

        func textViewDidChangeSelection(_ textView: TextView) {
            parent.onSelectionChange(textView.selectedRange)
            parent.controller.refreshUndoState()
        }
    }
}
