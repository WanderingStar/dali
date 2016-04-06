//
//  Persistence.swift
//  Dali
//
//  Created by Aneel Nazareth on 4/2/16.
//  Copyright © 2016 Aneel Nazareth. All rights reserved.
//

import Foundation

typealias JSONDoc = [String: AnyObject]

enum PersistenceError: ErrorType {
    case NoSuchDocument
    case MalformedDocument(document: JSONDoc?)
    case UnregisteredKind(kind: String)
    case KindMismatch(expected: Persistable.Type, actual: Persistable.Type)
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
        guard let json = document.properties?["data"] as? JSONDoc,
            kindKey = document.properties?["kind"] as? String
            else { throw PersistenceError.MalformedDocument(document: document.properties) }
        guard let kind = kinds[kindKey]
            else { throw PersistenceError.UnregisteredKind(kind: kindKey) }
        let loaded = kind.init(json: json)
        
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
    
    func save(persistable: Persistable) throws {
        if let document = database.documentWithID(persistable.identifier) {
            var properties = [String: AnyObject]()
            properties["kind"] = persistable.kind
            properties["data"] = persistable.toJSON()
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