//
//  Persistable.swift
//  Dali
//
//  Created by Aneel Nazareth on 4/2/16.
//  Copyright © 2016 Aneel Nazareth. All rights reserved.
//

import Foundation
import Gloss

protocol Persistable : AnyObject { // must be AnyObject so we can cache it
    var kind: String { get }
    var identifier: String { get }
    
    init?(with json: JSON, from persistence: Persistence) throws
    func save(to: Persistence) throws
}