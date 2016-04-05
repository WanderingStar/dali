//
//  Persistable.swift
//  Dali
//
//  Created by Aneel Nazareth on 4/2/16.
//  Copyright © 2016 Aneel Nazareth. All rights reserved.
//

import Foundation
import Gloss

protocol Persistable : Glossy, AnyObject {
    var kind: String { get }
    var identifier: String { get }
}