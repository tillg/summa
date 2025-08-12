//
//  DateExtension.swift
//  Summa
//
//  Created by Till Gartner on 11.08.25.
//

import Foundation

extension Date {
    init(daysSinceNow: Int) {
        let secondsSinceNow = Double(daysSinceNow * 24 * 60 * 60)
        self.init(timeIntervalSinceNow : secondsSinceNow)
    }
}
