//
//  Persistence.swift
//  Dali
//
//  Created by Aneel Nazareth on 4/2/16.
//  Copyright © 2016 Aneel Nazareth. All rights reserved.
//

import Foundation

class Persistence {
    private let database: CBLDatabase
    private let cache = NSMapTable(keyOptions: .StrongMemory, valueOptions: .WeakMemory)
    private var kinds = [String: Persistable.Type]()
    
    init?(databaseName: String) {
        do {
            database = try CBLManager.sharedInstance().databaseNamed(databaseName)
        } catch {
            return nil
        }
    }
    
    func register(kindKey: String, kind: Persistable.Type) {
        kinds[kindKey] = kind
    }
    
    func load(identifier: String) -> Persistable? {
        if let object = cache.objectForKey(identifier) {
            return object as? Persistable
        }
        guard let document = database.documentWithID(identifier),
            kindKey = document.properties?["_kind"] as? String,
            kind = kinds[kindKey],
            json = document.properties?["_object"] as? [String: AnyObject],
            loaded = kind.init(json: json)
            else { return nil }
        
        cache.setObject(loaded, forKey: identifier)
        return loaded
    }
    
    func load<T: Persistable>(identifier: String) -> T? {
        return load(identifier) as? T
    }
    
    func save(persistable: Persistable) -> Bool {
        guard let document = database.documentWithID(persistable.identifier) else { return false }
        var properties = [String: AnyObject]()
        properties["_kind"] = persistable.kind
        properties["_object"] = persistable.toJSON()
        if let _ = try? document.putProperties(properties) {
            return true
        }
        return false
    }
}