//
//  PlatformColor.swift
//  Summa
//
//  Cross-platform color type alias
//  Provides unified API for UIColor (iOS) and NSColor (macOS)
//

import Foundation

#if os(iOS)
import UIKit
public typealias PlatformColor = UIColor
#elseif os(macOS)
import AppKit
public typealias PlatformColor = NSColor
#endif
