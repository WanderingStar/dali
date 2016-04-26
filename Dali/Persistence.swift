//
//  Persistence.swift
//  Dali
//
//  Created by Aneel Nazareth on 4/2/16.
//  Copyright © 2016 Aneel Nazareth. All rights reserved.
//

import Foundation
import Gloss

enum PersistenceError: ErrorType {
    case NoSuchDocument
    case MalformedDocument(document: JSON?)
    case UnregisteredKind(kind: String)
    case KindMismatch(expected: Persistable.Type, actual: AnyObject.Type)
    case FailedTranslation
    case EncodingFailure(label: String)
    case NotEncodable(label: String?, value: Any)
    case LazyNotOptional(label: String)
}

protocol Persistable : AnyObject { // must be AnyObject so we can cache it
    static var kind: String { get }
    var identifier: String { get }
    
    init?(with json: JSON, from persistence: Persistence) throws
    var propertyMapping: [String: String?] { get }
    func save(to: Transaction) throws
}

extension Persistable {
    var defaultPropertyMapping: [String: String?] {
        return [
            "propertyMapping": nil,
            "kind": nil,
            "identifier": nil]
    }
    
    // anything mapped to nil will not be persisted
    var propertyMapping: [String: String?] {
        return defaultPropertyMapping
    }
    
    func save(to: Transaction) throws {
        guard to.needsSave(self) else { return }
        
        let mapping = propertyMapping
        let mirror = Mirror(reflecting: self)
        
        var json: JSON = [:]
        var referenced = [Persistable]()
        for (label, value) in mirror.children {
            guard var label = label else {
                throw PersistenceError.NotEncodable(label: nil, value: value)
            }
            var value = value
            if label.hasSuffix(".storage") { // HACK - lazy stored properties seem to have this
                label = label.substringToIndex(label.endIndex.advancedBy(-".storage".length))
                guard let optional = value as? OptionalProtocol
                    else { throw PersistenceError.LazyNotOptional(label: label) }
                if optional.isSome() {
                    value = optional.unwrap()
                } else {
                    value = NSNull()
                }
            }
            if let mapped = mapping[label] {
                guard let mapped = mapped else { continue }
                label = mapped
            }
            if let optional = value as? OptionalProtocol {
                if optional.isSome() {
                    value = optional.unwrap()
                } else {
                    value = NSNull()
                }
            }
            if let persistable = value as? Persistable {
                referenced.append(persistable)
                json[label] = persistable.identifier // TODO: implement key paths
            } else {
                guard let encoded = label ~~> value else {
                    throw PersistenceError.EncodingFailure(label: label)
                }
                json.add(encoded)
            }
        }
        // save this first, to prevent loops
        try to.save(self, json: json)
        for other in referenced {
            try other.save(to)
        }
    }
}

class Persistence {
    private let database: CBLDatabase
    private let cache = NSMapTable(keyOptions: .StrongMemory, valueOptions: .WeakMemory)
    private var kinds = [String: Persistable.Type]()
    private let kindView: CBLView
    
    init?(databaseName: String) throws {
        database = try CBLManager.sharedInstance().databaseNamed(databaseName)
        
        kindView = database.viewNamed("kind")
        kindView.setMapBlock({
            (doc, emit) in
            if let kind = doc["kind"] as? String {
                emit(kind, doc)
            }
            }, version: "2")
    }
    
    func viewNamed(name: String) -> CBLView {
        return database.viewNamed(name)
    }
    
    func deleteDatabase() throws {
        try database.deleteDatabase()
    }
    
    func register(persistableKind: Persistable.Type) {
        kinds[persistableKind.kind] = persistableKind
    }
    
    private func instantiate(identifier: String, kind key: String, json: JSON) throws -> Persistable? {
        guard let kind = kinds[key]
            else { throw PersistenceError.UnregisteredKind(kind: key) }
        if let object = cache.objectForKey(identifier) {
            return object as? Persistable
        }
        guard let object = try kind.init(with: json, from: self)
            else { return nil }
        cache.setObject(object, forKey: identifier)
        return object
    }
    
    func loadPersistable(identifier: String) throws -> Persistable? {
        if let object = cache.objectForKey(identifier) {
            return object as? Persistable
        }
        guard let document = database.documentWithID(identifier),
            properties = document.properties
            else { throw PersistenceError.NoSuchDocument }
        guard let json = properties["data"] as? JSON,
            kindKey = properties["kind"] as? String
            else { throw PersistenceError.MalformedDocument(document: properties) }
        return try instantiate(identifier, kind: kindKey, json: json)
    }
    
    func load<T: Persistable>(identifier: String?) throws -> T? {
        guard let identifier = identifier else { return nil }
        guard let loaded = try loadPersistable(identifier) else { return nil }
        if let loaded = loaded as? T {
            return loaded
        } else {
            throw PersistenceError.KindMismatch(expected: T.self, actual: loaded.dynamicType)
        }
    }
    
    func save(persistable: Persistable, json: JSON) throws {
        if let document = database.documentWithID(persistable.identifier) {
            var properties = [String: AnyObject]()
            properties["kind"] = persistable.dynamicType.kind
            properties["data"] = json
            print(properties)
            try document.putProperties(properties)
            cache.setObject(persistable, forKey: persistable.identifier)
        } else {
            throw PersistenceError.NoSuchDocument
        }
    }
    
    func delete(persistable: Persistable) throws {
        if let document = database.documentWithID(persistable.identifier) {
            try document.deleteDocument()
        }
    }
    
    func isCached(identifier: String) -> Bool {
        return cache.objectForKey(identifier) != nil
    }
    
    func loadResults(result: CBLQueryEnumerator) throws -> AnyGenerator<Persistable> {
        return AnyGenerator<Persistable> {
            while let row = result.nextRow() {
                guard let identifier = row.documentID,
                    document = row.value as? JSON,
                    kind = document["kind"] as? String,
                    json = document["data"] as? JSON,
                    object = try? self.instantiate(identifier, kind: kind, json: json)
                    else { continue } // skip invalid documents, if any
                return object
            }
            return nil
        }
    }
    
    func loadAll<T: Persistable>(kind: T.Type) throws -> AnyGenerator<T> {
        let query = kindView.createQuery()
        query.startKey = kind.kind
        query.endKey = kind.kind
        let results = try loadResults(query.run())
        return AnyGenerator<T> {
            while let object = results.next() {
                if let object = object as? T {
                    return object
                }
            }
            return nil
        }
    }
}

class Transaction {
    private let persistence: Persistence
    private var seen = Set<String>()
    
    init(on: Persistence) {
        persistence = on
    }
    
    func needsSave(persistable: Persistable) -> Bool {
        return !seen.contains(persistable.identifier)
    }
    
    func save(persistable: Persistable, json: JSON) throws {
        if needsSave(persistable) {
            seen.insert(persistable.identifier)
            try persistence.save(persistable, json: json)
        }
    }
    
}