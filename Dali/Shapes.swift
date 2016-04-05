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
    var kind: String { return "Shape" }
    let identifier = NSUUID().UUIDString
    
    init() { print("Init Shape")  }
    
    required init?(json: JSON) { print("Init Shape from JSON") }
    
    func toJSON() -> JSON? {
        return [:]
    }
    
    var area: Double {
        return 0.0
    }
}

class Square : Shape {
    override var kind: String { return "Square" }
    
    let side: Double
    
    init(side: Double) {
        print("Init Square") 
        self.side = side
        super.init()
    }
    
    required init?(json: JSON) {
        print("Init Square from JSON")
        guard let side: Double = "side" <~~ json else { return nil }
        self.side = side
        super.init(json: json)
    }
    
    override func toJSON() -> JSON? {
        return jsonify([
            "side" ~~> side
            ])
    }
    
    override var area: Double {
        return side * side
    }
}

class Circle : Shape {
    override var kind: String { return "Circle" }
    
    let radius: Double
    
    init(radius: Double) {
        print("Init Circle")
        self.radius = radius
        super.init()
    }
    
    required init?(json: JSON) {
        print("Init Circle from JSON")
        guard let radius: Double = "radius" <~~ json else { return nil }
        self.radius = radius
        super.init(json: json)
    }
    
    override func toJSON() -> JSON? {
        return jsonify([
            "radius" ~~> radius
            ])
    }
    
    override var area: Double {
        return M_PI * radius * radius
    }
}