//
//  WebViewModel.swift
//  youtube
//
//  Created by Alex Titarenko on 9/22/24.
//

import Foundation

class WebViewModel : ObservableObject {
    var url: String
    var userAgent: String?
    var styleSheets: [String]
    var scripts: [String]
    
    init(url: String, userAgent: String? = nil, styleSheets: [String] = [], scripts: [String] = []) {
        self.url = url
        self.userAgent = userAgent
        self.styleSheets = styleSheets
        self.scripts = scripts
    }
}
