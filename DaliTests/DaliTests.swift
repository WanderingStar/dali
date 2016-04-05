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
        let s = Square(side: 3)
        try persistence?.save(s)
        let s2: Square? = persistence?.load(s.identifier)
        XCTAssert(s2 != nil)
        XCTAssertEqualWithAccuracy(s.area, 9.0, accuracy: 0.001)
    }
    
    func testSavedSquareIsSame() throws {
        let s = Square(side: 3)
        try persistence?.save(s)
        let s2: Square? = persistence?.load(s.identifier)
        let s3: Square? = persistence?.load(s.identifier)
        XCTAssert(s2 === s3)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
