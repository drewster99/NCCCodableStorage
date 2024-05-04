//
//  NCCUnderlyingStorage.swift
//  
//
//  Created by Andrew Benson on 5/4/24.
//

import SwiftUI

protocol NCCUnderlyingStorage: ObservableObject {
    associatedtype T
    var value: T { get set }
    func save() throws
}
