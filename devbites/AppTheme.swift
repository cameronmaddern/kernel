//
//  AppTheme.swift
//  devbites
//
//  Brand accents align with `AccentColor` and the KERNEL wordmark asset (`KERNEL` in Assets).
//

import SwiftUI
import UIKit

enum AppTheme {
    /// Primary brand orange — `#FF8000` (matches light-mode `AccentColor`)
    static let brandOrange = Color(hex: "FF8000")

    // MARK: Light

    static let inkLight = Color(hex: "1A1A1A")
    static let mutedLight = Color(hex: "5C5C5C")
    static let dimLight = Color(hex: "8E8E8E")
    static let borderLight = Color(hex: "E5E5EA")

    // MARK: Adaptive

    static let canvas = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1)
        }
        return .white
    })

    /// Navigation bar & tab bar surface (opaque white / dark elevated).
    static let navChrome = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        }
        return .white
    })

    static let ink = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(white: 0.96, alpha: 1)
        }
        return UIColor(AppTheme.inkLight)
    })

    static let inkMuted = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(white: 0.65, alpha: 1)
        }
        return UIColor(AppTheme.mutedLight)
    })

    static let inkTertiary = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(white: 0.48, alpha: 1)
        }
        return UIColor(AppTheme.dimLight)
    })

    static let hairline = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(white: 0.22, alpha: 1)
        }
        return UIColor(AppTheme.borderLight)
    })

    static var canvasUIColor: UIColor {
        UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 1)
            }
            return .white
        }
    }
}
