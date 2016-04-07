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
    
    var area: Double {
        return 0.0
    }
    
    init() { print("Init Shape")  }
    
    required init?(json: JSON) { print("Init Shape from JSON") }
    
    required convenience init?(json: JSON, from persistence: Persistence) throws { self.init(json: json) }
    
    func toJSON() -> JSON? {
        return [:]
    }
    
    func save(to: Persistence) throws {
        try to.save(self)
    }
}

class Square : Shape {
    override var kind: String { return "Square" }
    
    let side: Double
    
    override var area: Double {
        return side * side
    }
    
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
    
    required convenience init?(json: JSON, from persistence: Persistence) throws { self.init(json: json) }
    
    override func toJSON() -> JSON? {
        return jsonify([
            "side" ~~> side
            ])
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
    
    required convenience init?(json: JSON, from persistence: Persistence) throws { self.init(json: json) }
    
    override func toJSON() -> JSON? {
        return jsonify([
            "radius" ~~> radius
            ])
    }
    
    override var area: Double {
        return M_PI * radius * radius
    }
}

class VennDiagram : Persistable {
    let kind = "VennDiagram"
    let identifier = NSUUID().UUIDString
    
    let left: Circle
    let right: Circle
    
    init(left: Circle, right: Circle) {
        self.left = left
        self.right = right
    }
    
    required init?(json: JSON) {
        guard let left: Circle = "left" <~~ json,
            right: Circle = "right" <~~ json
            else { return nil }
        self.left = left
        self.right = right
    }
    
    required init?(json: JSON, from persistence: Persistence) throws {
        guard let left: Circle = try persistence.resolve("left", json: json),
            right: Circle = try persistence.resolve("right", json: json)
            else { return nil }
        self.left = left
        self.right = right
    }
    
    func toJSON() -> JSON? {
        return jsonify([
            "left" ~~> left,
            "right" ~~> right])
    }
    
    func save(to: Persistence) throws {
        try left.save(to)
        try right.save(to)
        guard let json = jsonify([
            "left" ~~> left.identifier,
            "right" ~~> right.identifier])
            else { throw PersistenceError.MalformedDocument(document: nil) }
        try to.save(self, json: json)
    }
    
}