//
//  Graph.swift
//  Dali
//
//  Created by Aneel Nazareth on 4/10/16.
//  Copyright © 2016 Aneel Nazareth. All rights reserved.
//

import Foundation
import Gloss

final class Edge : Persistable {
    static let kind = "Edge"
    let identifier = NSUUID().UUIDString
    
    let from: Node
    let to: Node
    let weight: Double
    
    init(from: Node, to: Node, weight: Double) {
        self.from = from
        self.to = to
        self.weight = weight
    }
    
    init?(with json: JSON, from persistence: Persistence) throws {
        guard let from: Node = try persistence.load("from" <~~ json),
            to: Node = try persistence.load("to" <~~ json),
            weight: Double = "weight" <~~ json
            else { return nil }
        self.from = from
        self.to = to
        self.weight = weight
    }
    
    func save(to: Persistence) throws {
        try to.save(self, json: [
            "from": from.identifier,
            "to": self.to.identifier,
            "weight": weight])
    }
}
extension Edge : Hashable, Equatable {
    var hashValue: Int { return identifier.hashValue }
}
func ==(lhs: Edge, rhs: Edge) -> Bool {
    return lhs.identifier == rhs.identifier
}


final class Node : Persistable {
    static let kind = "Node"
    let identifier = NSUUID().UUIDString
    
    var labels = Set<String>()
    var outEdges = Set<Edge>()
    
    init() { }
    
    func addLabel(label: String) {
        labels.insert(label)
    }
    
    func connectTo(node: Node, weight: Double) {
        precondition(weight >= 0)
        let edge = Edge(from: self, to: node, weight: weight)
        outEdges.insert(edge)
    }
    
    init?(with json: JSON, from persistence: Persistence) throws {
        guard let labels: [String] = "labels" <~~ json,
            outEdgeIdentifiers: [String] = "outEdges" <~~ json
            else { return nil }
        self.labels = Set<String>(labels)
        self.outEdges = Set<Edge>(try outEdgeIdentifiers.map { try persistence.load($0) as Edge!})
    }
    
    func save(to: Persistence) throws {
        try to.save(self, json: jsonify([
            "labels" ~~> [String](self.labels),
            "outEdges" ~~> outEdges.map { $0.identifier }
            ])!)
    }
    
    func minDistance(destination: Node) -> Double? {
        addLabel("visited")
        for edge in outEdges {
            if edge.to == destination {
                return edge.weight
            }
        }
        var minDistance: Double?
        for edge in outEdges {
            if !edge.to.labels.contains("visited"),
                let distance = edge.to.minDistance(destination) {
                if let oldMin = minDistance {
                    minDistance = min(oldMin, distance)
                } else {
                    minDistance = distance
                }
            }
        }
        return minDistance
    }
}
extension Node : Equatable, Hashable {
    var hashValue: Int { return identifier.hashValue }
}
func ==(lhs: Node, rhs: Node) -> Bool {
    return lhs.identifier == rhs.identifier
}



