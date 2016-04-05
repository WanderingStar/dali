//
//  Persistence.swift
//  Dali
//
//  Created by Aneel Nazareth on 4/2/16.
//  Copyright © 2016 Aneel Nazareth. All rights reserved.
//

import Foundation

enum PersistenceError: ErrorType {
    case NoSuchDocument
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
    
    func loadPersistable(identifier: String) -> Persistable? {
        if let object = cache.objectForKey(identifier) {
            return object as? Persistable
        }
        guard let document = database.documentWithID(identifier),
            kindKey = document.properties?["kind"] as? String,
            kind = kinds[kindKey],
            json = document.properties?["data"] as? [String: AnyObject],
            loaded = kind.init(json: json)
            else { return nil }
        
        cache.setObject(loaded, forKey: identifier)
        return loaded
    }
    
    func load<T: Persistable>(identifier: String) -> T? {
        return loadPersistable(identifier) as? T
    }
    
    func save(persistable: Persistable) throws {
        if let document = database.documentWithID(persistable.identifier) {
            var properties = [String: AnyObject]()
            properties["kind"] = persistable.kind
            properties["data"] = persistable.toJSON()
            print(properties)
            try document.putProperties(properties)
        } else {
            throw PersistenceError.NoSuchDocument
        }
    }
    
    func delete(persistable: Persistable) throws {
        if let document = database.documentWithID(persistable.identifier) {
            try document.deleteDocument()
        }
    }
}