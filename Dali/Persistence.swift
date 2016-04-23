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
    case KindMismatch(expected: Persistable.Type, actual: Persistable.Type)
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
                emit(kind, doc["data"])
            }
            }, version: "1")
    }
    
    func deleteDatabase() throws {
        try database.deleteDatabase()
    }
    
    func register(persistableKind: Persistable.Type) {
        kinds[persistableKind.kind] = persistableKind
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
        guard let kind = kinds[kindKey]
            else { throw PersistenceError.UnregisteredKind(kind: kindKey) }
        let loaded = try kind.init(with: json, from: self)
        
        cache.setObject(loaded, forKey: identifier)
        return loaded
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
    
    func loadAll<T: Persistable>() throws -> AnyGenerator<T> {
        guard let kind = kinds[T.kind] else { throw PersistenceError.UnregisteredKind(kind: T.kind) }
        let query = kindView.createQuery()
        query.startKey = T.kind
        query.endKey = T.kind
        let result = try query.run()
        return AnyGenerator<T> {
            guard let row = result.nextRow() else { return nil }
            if let object = self.cache.objectForKey(row.documentID) {
                return object as? T
            }
            guard let json = row.value as? JSON,
                object = try? kind.init(with: json, from: self) as? T
                else { return nil }
            self.cache.setObject(object, forKey: row.documentID)
            return object
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