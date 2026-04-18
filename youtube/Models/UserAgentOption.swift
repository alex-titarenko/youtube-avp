//
//  UserAgentOption.swift
//  youtube
//

import Foundation

enum UserAgentOption: String, CaseIterable, Identifiable {
    case systemDefault
    case chrome

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .systemDefault: "Default"
        case .chrome: "Chrome"
        }
    }

    var userAgentString: String? {
        switch self {
        case .systemDefault: nil
        case .chrome: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0"
        }
    }
}
