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

class Persistence {
    private let database: CBLDatabase
    private let cache = NSMapTable(keyOptions: .StrongMemory, valueOptions: .WeakMemory)
    private var kinds = [String: Persistable.Type]()
    
    init?(databaseName: String) throws {
        database = try CBLManager.sharedInstance().databaseNamed(databaseName)
    }
    
    func deleteDatabase() throws {
        try database.deleteDatabase()
    }
    
    func register(kindKey: String, kind: Persistable.Type) {
        kinds[kindKey] = kind
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
    
    func load<T: Persistable>(identifier: String) throws -> T? {
        guard let loaded = try loadPersistable(identifier) else { return nil }
        if let loaded = loaded as? T {
            return loaded
        } else {
            throw PersistenceError.KindMismatch(expected: T.self, actual: loaded.dynamicType)
        }
    }
    
    func resolve<T: Persistable>(keyPath: String, json: JSON) throws -> T? {
        if let it: T = keyPath <~~ json {
            return it
        }
        if let identifier: String = keyPath <~~ json {
            guard let it: T = try load(identifier) else { return nil }
            return it
        }
        return nil
    }
    
    func save(persistable: Persistable, json: JSON) throws {
        if let document = database.documentWithID(persistable.identifier) {
            var properties = [String: AnyObject]()
            properties["kind"] = persistable.kind
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
}