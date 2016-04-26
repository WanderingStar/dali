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
    class var kind: String { return "Shape" }
    let identifier = NSUUID().UUIDString
    
    var area: Double {
        return 0.0
    }
    
    init() { print("Init Shape")  }
    
    required init?(with json: JSON, from persistence: Persistence) throws {
        print("Init Shape from JSON")
    }
}

class Square : Shape {
    override class var kind: String { return "Square" }
    
    let side: Double
    
    override var area: Double {
        return side * side
    }
    
    init(side: Double) {
        print("Init Square") 
        self.side = side
        super.init()
    }
    
    required init?(with json: JSON, from persistence: Persistence) throws {
        print("Init Square from JSON")
        guard let side: Double = "side" <~~ json else { return nil }
        self.side = side
        try super.init(with: json, from: persistence)
    }
}

class Circle : Shape {
    override class var kind: String { return "Circle" }
    
    let radius: Double
    
    override var area: Double {
        return M_PI * radius * radius
    }
    
    init(radius: Double) {
        print("Init Circle")
        self.radius = radius
        super.init()
    }
    
    required init?(with json: JSON, from persistence: Persistence) throws {
        print("Init Circle from JSON")
        guard let radius: Double = "radius" <~~ json else { return nil }
        self.radius = radius
        try super.init(with: json, from: persistence)

    }
}

final class VennDiagram : Persistable {
    static let kind = "VennDiagram"
    let identifier = NSUUID().UUIDString
    
    let left: Circle
    let right: Circle
    
    init(left: Circle, right: Circle) {
        self.left = left
        self.right = right
    }
    
    required init?(with json: JSON, from persistence: Persistence) throws {
        guard let left: Circle = try persistence.load("left" <~~ json),
            right: Circle = try persistence.load("right" <~~ json)
            else { return nil }
        self.left = left
        self.right = right
    }
}

final class LazySquare : Persistable {
    static let kind = "LazySquare"
    let identifier = NSUUID().UUIDString
    
    private weak var persistence: Persistence?
    private var squareIdentifier: String?
    lazy var square: Square? = try! self.persistence?.load(self.squareIdentifier)
    
    init(square: Square) {
        self.square = square
    }
    
    required init?(with json: JSON, from persistence: Persistence) throws {
        self.persistence = persistence
        self.squareIdentifier = "square" <~~ json
    }
    
    var propertyMapping: [String : String?] {
        var mapping = defaultPropertyMapping
        mapping.updateValue(nil, forKey: "persistence")
        mapping.updateValue(nil, forKey: "squareIdentifier")
        return mapping
    }
}

final class Chain : Persistable {
    static let kind = "Chain"
    let identifier = NSUUID().UUIDString
    
    let link: Circle
    var next: Chain?
    
    init(link: Circle) {
        self.link = link
    }
    
    required init?(with json: JSON, from persistence: Persistence) throws {
        guard let link: Circle = try persistence.load("link" <~~ json)
            else { return nil }
        self.link = link
        self.next = try persistence.load("next" <~~ json)
    }
}



