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
            return .custom("HelveticaNeue-Bold", size: 34, relativeTo: .largeTitle)
        case .title:
            return .custom("HelveticaNeue-Medium", size: 22, relativeTo: .title)
        case .headline:
            return .custom("HelveticaNeue-Medium", size: 17, relativeTo: .headline)
        case .body:
            return .custom("HelveticaNeue", size: 15, relativeTo: .body)
        case .caption:
            return .custom("HelveticaNeue", size: 12, relativeTo: .caption)
        }
    }
}