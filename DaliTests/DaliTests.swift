//
//  DaliTests.swift
//  DaliTests
//
//  Created by Aneel Nazareth on 4/2/16.
//  Copyright © 2016 Aneel Nazareth. All rights reserved.
//

import XCTest
@testable import Dali

class DaliTests: XCTestCase {
    
    var persistence: Persistence?
    
    override func setUp() {
        super.setUp()
        try! persistence = Persistence(databaseName: "dali_tests")
        persistence?.register(Circle.self)
        persistence?.register(Square.self)
        persistence?.register(VennDiagram.self)
        persistence?.register(LazySquare.self)
        persistence?.register(Chain.self)
    }
    
    override func tearDown() {
        do {
            try persistence?.deleteDatabase()
        } catch {
            
        }
        
        super.tearDown()
    }
    
    func testUnsavedSquare() {
        let s = Square(side: 3)
        XCTAssertEqualWithAccuracy(s.area, 9.0, accuracy: 0.001)
    }
    
    func testSavedSquare() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        let s1 = Square(side: 3)
        try s1.save(Transaction(on: persistence))
        let s2: Square? = try persistence.load(s1.identifier)
        XCTAssert(s2 != nil)
        XCTAssertEqualWithAccuracy(s1.area, 9.0, accuracy: 0.001)
    }
    
    func testCachedSquareIsSame() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        let s1 = Square(side: 3)
        try s1.save(Transaction(on: persistence))
        let s2: Square? = try persistence.load(s1.identifier)
        XCTAssert(s1 === s2)
    }
    
    func testRetrievedSquaresAreSame() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        // create and persist a Square, but don't hold a reference to it
        let identifier = try  {
            () -> String in
            let s1 = Square(side: 2)
            try s1.save(Transaction(on: persistence))
            return s1.identifier
        }()
        XCTAssertFalse(persistence.isCached(identifier))
        let s2: Square? = try persistence.load(identifier)
        let s3: Square? = try persistence.load(identifier)
        XCTAssert(s2 === s3)
    }
    
    func testMixedKinds() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        let (squareId, circleId) = try { () -> (String, String) in
            let s1 = Square(side: 3)
            let c1 = Circle(radius: 4)
            try s1.save(Transaction(on: persistence))
            try c1.save(Transaction(on: persistence))
            return (s1.identifier, c1.identifier)
        }()
        XCTAssertFalse(persistence.isCached(squareId))
        XCTAssertFalse(persistence.isCached(circleId))
        let s2: Square? = try persistence.load(squareId)
        XCTAssertNotNil(s2)
        XCTAssertEqualWithAccuracy(3.0, s2?.side ?? -1.0, accuracy: 0.001)
        let c2: Circle? = try persistence.load(circleId)
        XCTAssertNotNil(c2)
        XCTAssertEqualWithAccuracy(4.0, c2?.radius ?? -1.0, accuracy: 0.001)
    }
    
    func testWrongKind() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        let identifier = try  {
            () -> String in
            let s1 = Square(side: 2)
            try s1.save(Transaction(on: persistence))
            return s1.identifier
            }()

        var c1: Circle?
        do {
            c1 = try persistence.load(identifier)
            XCTFail("Should throw")
        } catch PersistenceError.KindMismatch(let expected, let actual) {
            XCTAssert(Circle.self == expected)
            XCTAssert(Square.self == actual)
        }
        XCTAssertNil(c1)
    }
    
    func testNested() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        let identifier = try {
            () -> String in
            let venn = VennDiagram(left: Circle(radius: 3), right: Circle(radius: 4))
            try venn.save(Transaction(on: persistence))
            return venn.identifier
            }()
        
        let v1: VennDiagram? = try persistence.load(identifier)
        XCTAssertEqual(v1?.left.radius, 3.0)
        XCTAssertEqual(v1?.right.radius, 4.0)
        
    }
    
    func testLazy() throws {
        guard let persistence = persistence else { XCTFail(); return }

        let (squareIdentifier, lazyIdentifier) = try {
            () -> (String, String) in
            let square = Square(side: 5.0)
            let lazy = LazySquare(square: square)
            try lazy.save(Transaction(on: persistence))
            return (square.identifier, lazy.identifier)
        }()
        
        XCTAssertFalse(persistence.isCached(lazyIdentifier))
        let l1: LazySquare? = try persistence.load(lazyIdentifier)
        XCTAssertFalse(persistence.isCached(squareIdentifier))
        XCTAssertEqual(l1?.square?.area, 25.0)
        XCTAssertTrue(persistence.isCached(squareIdentifier))
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
    func test2Links() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        let identifier = try {
            () -> String in
            let link1 = Chain(link: Circle(radius: 1))
            let link2 = Chain(link: Circle(radius: 2))
            link1.next = link2
            
            try link1.save(Transaction(on: persistence))
            return link1.identifier
        }()
        
        let link1: Chain? = try persistence.load(identifier)
        XCTAssertEqual(link1?.link.radius, 1.0)
        XCTAssertEqual(link1?.next?.link.radius, 2.0)
    }
    
    func testLoop() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        let identifier = try {
            () -> String in
            let link1 = Chain(link: Circle(radius: 1))
            let link2 = Chain(link: Circle(radius: 2))
            link1.next = link2
            link2.next = link1
            
            try link1.save(Transaction(on: persistence))
            return link1.identifier
            }()
        
        let link1: Chain? = try persistence.load(identifier)
        XCTAssertEqual(link1?.link.radius, 1.0)
        XCTAssertEqual(link1?.next?.link.radius, 2.0)
        XCTAssertEqual(link1?.next?.next?.link.radius, 1.0)
    }
    
    func testLoadAll() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        try {
            let transaction = Transaction(on: persistence)
            for d in 1.0.stride(to: 100.0, by: 1.0) {
                try Square(side: d).save(transaction)
                try Circle(radius: d).save(transaction)
            }
        }()
        var seen = Set<Double>()
        for square in try persistence.loadAll(Square.self) {
            seen.insert(square.side)
        }
        for d in 1.0.stride(to: 100.0, by: 1.0) {
            XCTAssertTrue(seen.contains(d))
        }
    }
    
    func testLoadAllCachedSame() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        let square = Square(side: 3)
        try square.save(Transaction(on: persistence))
        
        let squares = try persistence.loadAll(Square.self)
        XCTAssertTrue(square === squares.next())
    }
    
    func testLoadAllLazy() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        let identfier = try {
            () -> String in
            let square = Square(side: 3)
            try square.save(Transaction(on: persistence))
            return square.identifier
            }()
        
        XCTAssertFalse(persistence.isCached(identfier))
        let squares = try persistence.loadAll(Square.self)
        XCTAssertFalse(persistence.isCached(identfier))
        let square = squares.next()
        XCTAssertEqual(square?.side, 3.0)
        XCTAssertTrue(persistence.isCached(identfier))
    }
    
}
