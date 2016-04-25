//
//  OptionalProtocol.swift
//  Dali
//
//  http://stackoverflow.com/a/32780793/1115020
//

import Foundation

protocol OptionalProtocol {
    func isSome() -> Bool
    func unwrap() -> Any
}

extension Optional : OptionalProtocol {
    func isSome() -> Bool {
        switch self {
        case .None: return false
        case .Some: return true
        }
    }
    
    func unwrap() -> Any {
        switch self {
        // If a nil is unwrapped it will crash!
        case .None: preconditionFailure("nil unwrap")
        case .Some(let unwrapped): return unwrapped
        }
    }
}
