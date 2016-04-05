//
//  Shape.swift
//  Dali
//
//  Created by Aneel Nazareth on 4/2/16.
//  Copyright © 2016 Aneel Nazareth. All rights reserved.
//

import Foundation
import Gloss

class Shape : Persistable {
    let kind: String
    let identifier: String
    
    init(kind: String) {
        self.kind = kind
        self.identifier = NSUUID().UUIDString
    }
    
    init(kind: String, identifier: String) {
        self.kind = kind
        self.identifier = identifier
    }
    
    required init?(json: JSON) {
        guard let kind: String = "_kind" <~~ json,
        identifier: String = "_id" <~~ json
            else { return nil }
        self.kind = kind
        self.identifier = identifier
    }
    
    func toJSON() -> JSON? {
        return ["_kind": kind, "_id": identifier]
    }
    
    func area() -> Double {
        return 0.0
    }
}

class Square : Shape {
    let side: Double
    
    init(side: Double) {
        self.side = side
        super.init(kind: "Square")
    }
    
    required init?(json: JSON) {
        guard let side: Double = "side" <~~ json else { return nil }
        self.side = side
        super.init(json: json)
    }
    
    override func toJSON() -> JSON? {
        return jsonify([
            super.toJSON(),
            "side" ~~> side
            ])
    }
    
    override func area() -> Double {
        return side * side
    }
}

class Circle : Shape {
    let radius: Double
    
    init(radius: Double) {
        self.radius = radius
        super.init(kind: "Circle")
    }
    
    required init?(json: JSON) {
        guard let radius: Double = "radius" <~~ json else { return nil }
        self.radius = radius
        super.init(json: json)
    }
    
    override func toJSON() -> JSON? {
        return jsonify([
            super.toJSON(),
            "radius" ~~> radius
            ])
    }
    
    override func area() -> Double {
        return M_PI * radius * radius
    }
}