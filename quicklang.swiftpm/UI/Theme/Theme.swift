//
//  Theme.swift
//  quicklang
//
//  Created by Rob Patterson on 11/26/25.
//

import UIKit

// always cast UIFont to Any, you'll get a warning for some reason
struct Theme {
    
    static var `default`: Theme {
        Theme(
            plainText: [
                .foregroundColor: UIColor.white,
                .font: UIFont(name: "Menlo", size: 18) as Any
            ],
            keyword: [
                .foregroundColor: UIColor(red: 212 / 255, green: 102 / 255, blue: 149 / 255, alpha: 1),
                .font: UIFont(name: "Menlo-Bold", size: 18) as Any
            ],
            numLiteral: [
                .foregroundColor: UIColor(red: 218 / 255, green: 200 / 255, blue: 124 / 255, alpha: 1)
            ],
            booleanLiteral: [
                .foregroundColor: UIColor(red: 212 / 255, green: 102 / 255, blue: 149 / 255, alpha: 1),
                .font: UIFont(name: "Menlo-Bold", size: 18) as Any
            ]
        )
    }
    
    private init(
        plainText: [NSAttributedString.Key : Any],
        keyword: [NSAttributedString.Key : Any],
        numLiteral: [NSAttributedString.Key : Any],
        booleanLiteral: [NSAttributedString.Key : Any]
    ) {
        self.plainText = plainText
        self.keyword = keyword
        self.numLiteral = numLiteral
        self.booleanLiteral = booleanLiteral
    }
    
    let font = UIFont(name: "Menlo", size: 18)
    let plainText: [NSAttributedString.Key : Any]
    let keyword: [NSAttributedString.Key: Any]
    let numLiteral: [NSAttributedString.Key: Any]
    let booleanLiteral: [NSAttributedString.Key: Any]
}
