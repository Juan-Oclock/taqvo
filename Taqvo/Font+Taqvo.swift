//
//  Font+Taqvo.swift
//  Taqvo
//
//  Adds Helvetica Neue helper per PRD.
//

import SwiftUI

public enum TaqvoFontStyle {
    case largeTitle
    case title
    case headline
    case body
    case caption
}

public extension Font {
    static func taqvo(_ style: TaqvoFontStyle) -> Font {
        switch style {
        case .largeTitle:
            return .custom("Helvetica Neue", size: 34, relativeTo: .largeTitle)
        case .title:
            return .custom("Helvetica Neue", size: 22, relativeTo: .title)
        case .headline:
            return .custom("Helvetica Neue", size: 17, relativeTo: .headline)
        case .body:
            return .custom("Helvetica Neue", size: 15, relativeTo: .body)
        case .caption:
            return .custom("Helvetica Neue", size: 12, relativeTo: .caption)
        }
    }
}