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
        persistence?.register("Circle", kind: Circle.self)
        persistence?.register("Square", kind: Square.self)
        persistence?.register("VennDiagram", kind: VennDiagram.self)
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
        try persistence.save(s1)
        let s2: Square? = try persistence.load(s1.identifier)
        XCTAssert(s2 != nil)
        XCTAssertEqualWithAccuracy(s1.area, 9.0, accuracy: 0.001)
    }
    
    func testCachedSquareIsSame() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        let s1 = Square(side: 3)
        try persistence.save(s1)
        let s2: Square? = try persistence.load(s1.identifier)
        XCTAssert(s1 === s2)
    }
    
    func testRetrievedSquaresAreSame() throws {
        guard let persistence = persistence else { XCTFail(); return }
        
        // create and persist a Square, but don't hold a reference to it
        let identifier = try  {
            () -> String in
            let s1 = Square(side: 2)
            try persistence.save(s1)
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
            try persistence.save(s1)
            try persistence.save(c1)
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
            try persistence.save(s1)
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
            try venn.save(persistence)
            return venn.identifier
            }()
        
        let v1: VennDiagram? = try persistence.load(identifier)
        XCTAssertEqual(v1?.left.radius, 3.0)
        XCTAssertEqual(v1?.right.radius, 4.0)
        
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
