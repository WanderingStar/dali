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
}

protocol Persistable : AnyObject { // must be AnyObject so we can cache it
    static var kind: String { get }
    var identifier: String { get }
    
    init?(with json: JSON, from persistence: Persistence) throws
    func save(to: Transaction) throws
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
        guard let document = database.documentWithID(identifier)
            else { throw PersistenceError.NoSuchDocument }
        guard let json = document.properties?["data"] as? JSON,
            kindKey = document.properties?["kind"] as? String
            else { throw PersistenceError.MalformedDocument(document: document.properties) }
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
    
    func loadAllOfKind(kindKey: String) throws -> AnyGenerator<Persistable> {
        let query = kindView.createQuery()
        query.startKey = kindKey
        query.endKey = kindKey
        let result = try query.run()
        return try loadResults(result)
    }
    
    func loadAll<T: Persistable>(kind: T.Type) throws -> AnyGenerator<T> {
        let results = try loadAllOfKind(T.kind)
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