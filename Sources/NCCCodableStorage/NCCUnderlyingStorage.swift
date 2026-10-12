//
//  NCCUnderlyingStorage.swift
//  
//
//  Created by Andrew Benson on 5/4/24.
//  Licensed under the MIT License. See LICENSE in the package root.
//

import SwiftUI

protocol NCCUnderlyingStorage: ObservableObject {
    associatedtype T
    var value: T { get set }
    func save() throws
}
