//
//  PinboardLoginController.swift
//  browse
//
//  Created by Evan Brooks on 3/8/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class PinboardLoginController: UIAlertController {

    convenience init(success: @escaping () -> (), failure: @escaping () ->()) {
        self.init(title: "To save pages, enter your Pinboard API key", message: nil, preferredStyle: .alert)
        addTextField { field in
            field.keyboardAppearance = .dark
            field.placeholder = "username:NNNNNN"
            field.returnKeyType = .continue
            field.addTarget(self, action: #selector(self.textDidChangeInLoginAlert), for: .editingChanged)
        }
        addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        let submitAction = UIAlertAction(title: "Add", style: .default, handler: { action in
            if let field = self.textFields?.first, let token = field.text {
                BookmarkProvider.shared.setAuthToken(token) { isValid in
                    if isValid { success() }
                    else { failure() }
                }
            }
        })
        submitAction.isEnabled = false
        addAction(submitAction)
    }
    
    func isValidToken(_ token: String) -> Bool {
        // ^ start
        // [ username characters (alphanumeric, dot, underscore)]{ more than 2}
        // colon
        // [ token characters (capital A to G, digits)]{ more than 16 }
        // $ end
        return token.matches("^[a-zA-Z0-9._]{2,}:[A-G0-9]{16,}$")
    }
    
    @objc func textDidChangeInLoginAlert() {
        if let text = textFields?.first?.text, let action = actions.last {
            action.isEnabled = isValidToken(text)
        }
    }
}

fileprivate extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}
