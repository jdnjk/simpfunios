//
//  EditorTheme.swift
//  simpfun
//
//  编辑器外观。颜色全部使用系统动态色，跟随浅色 / 深色模式自动切换。
//

import Runestone
import UIKit

nonisolated final class EditorTheme: Theme {
    static let shared = EditorTheme()

    private let fontSize: CGFloat = 14

    var font: UIFont {
        .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    var textColor: UIColor { .label }

    var gutterBackgroundColor: UIColor { .secondarySystemBackground }
    var gutterHairlineColor: UIColor { .separator }
    var lineNumberColor: UIColor { .secondaryLabel }

    var lineNumberFont: UIFont {
        .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    }

    var selectedLineBackgroundColor: UIColor { UIColor.label.withAlphaComponent(0.04) }
    var selectedLinesLineNumberColor: UIColor { .secondaryLabel }
    var selectedLinesGutterBackgroundColor: UIColor { .secondarySystemBackground }

    var invisibleCharactersColor: UIColor { .tertiaryLabel }

    var pageGuideHairlineColor: UIColor { .separator }
    var pageGuideBackgroundColor: UIColor { UIColor.label.withAlphaComponent(0.03) }

    var markedTextBackgroundColor: UIColor { .systemFill }

    func textColor(for highlightName: String) -> UIColor? {
        // Tree-sitter 的捕获名可能带层级，例如 keyword.function、string.escape。
        let base = highlightName.split(separator: ".").first.map(String.init) ?? highlightName

        switch base {
        case "comment":
            return .systemGreen
        case "keyword":
            return .systemPink
        case "string":
            return .systemRed
        case "number":
            return .systemBlue
        case "constant":
            return .systemOrange
        case "type":
            return .systemTeal
        case "constructor":
            return .systemTeal
        case "function":
            return .systemIndigo
        case "property":
            return .systemTeal
        case "operator":
            return .secondaryLabel
        case "punctuation":
            return .secondaryLabel
        default:
            return nil
        }
    }

    func fontTraits(for highlightName: String) -> FontTraits {
        let base = highlightName.split(separator: ".").first.map(String.init) ?? highlightName
        return base == "keyword" ? .bold : []
    }
}
