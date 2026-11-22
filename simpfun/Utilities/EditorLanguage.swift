//
//  EditorLanguage.swift
//  simpfun
//
//  把编辑器里的「语法」选项映射到 Tree-sitter 语言。
//  语言的查询文件只需加载一次，这里用静态常量做缓存。
//

import Runestone
import TreeSitterBashRunestone
import TreeSitterCSSRunestone
import TreeSitterHTMLRunestone
import TreeSitterJSONRunestone
import TreeSitterJavaRunestone
import TreeSitterJavaScriptRunestone
import TreeSitterLuaRunestone
import TreeSitterMarkdownRunestone
import TreeSitterPythonRunestone
import TreeSitterTOMLRunestone
import TreeSitterYAMLRunestone

private enum LanguageCache {
    static let bash = TreeSitterLanguage.bash
    static let json = TreeSitterLanguage.json
    static let yaml = TreeSitterLanguage.yaml
    static let toml = TreeSitterLanguage.toml
    static let java = TreeSitterLanguage.java
    static let javaScript = TreeSitterLanguage.javaScript
    static let python = TreeSitterLanguage.python
    static let lua = TreeSitterLanguage.lua
    static let html = TreeSitterLanguage.html
    static let css = TreeSitterLanguage.css
    static let markdown = TreeSitterLanguage.markdown
}

extension SyntaxLanguage {
    /// `nil` 表示不做语法分析，纯文本显示。
    var treeSitterLanguage: TreeSitterLanguage? {
        switch self {
        case .plain: return nil
        case .shell: return LanguageCache.bash
        case .json: return LanguageCache.json
        case .yaml: return LanguageCache.yaml
        case .toml: return LanguageCache.toml
        case .java: return LanguageCache.java
        case .javascript: return LanguageCache.javaScript
        case .python: return LanguageCache.python
        case .lua: return LanguageCache.lua
        case .html: return LanguageCache.html
        case .css: return LanguageCache.css
        case .markdown: return LanguageCache.markdown
        }
    }
}
