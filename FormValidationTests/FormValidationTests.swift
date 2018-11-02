//
//  FormValidationTests.swift
//  FormValidationTests
//
//  Created by Maxim Kovalko on 11/2/18.
//  Copyright © 2018 Maxim Kovalko. All rights reserved.
//

import XCTest
@testable import FormValidation

class FormValidationTests: XCTestCase {
    
    let missingErrors: [PartialKeyPath<User>: String] = [
        \User.firstName: "Missed first name",
        \User.lastName: "Missed last name"
    ]
    
    let invalidErrors: [PartialKeyPath<User>: String] = [
        \User.lastName: "LastName should containts more than 5 symbols",
        \User.age: "Age should be more than 18"
    ]
    
    func testPartial() {
        let partial = User(firstName: "foo", lastName: "bar", age: 17).partial()
        
        XCTAssertEqual(try partial.value(for: \.firstName), "foo")
        XCTAssertEqual(try partial.value(for: \.lastName), "bar")
        XCTAssertEqual(partial.value(for: \.age), 17)
    }
    
    func testRequiredFields() {
        let partial = User(firstName: "", lastName: "", age: nil).partial()
        let validation = Partial<User>.Validation(
            .valueValidation(keyPath: \User.firstName, block: { !$0.isEmpty }),
            .valueValidation(keyPath: \User.lastName, block: { !$0.isEmpty }),
            .required(\User.age)
        )
        XCTAssertNil(partial.value(for: \.age))
        
        let result = validation.validate(partial)
        XCTAssertEqual(result.reasons.count, 2)
    }

    func testValidation() {
        let partial = User(firstName: "foo", lastName: "bar", age: 17).partial()
        
        let validation = Partial<User>.Validation(
            .required(\User.firstName),
            .valueValidation(keyPath: \User.firstName, block: { !$0.isEmpty }),
            .required(\User.lastName),
            .valueValidation(keyPath: \User.lastName, block: { $0.count > 5 }),
            .valueValidation(keyPath: \User.age, block: { $0! >= 18 })
        )
        
        let result = validation.validate(partial)
     
        XCTAssertTrue(!result.reasons.isEmpty)
        XCTAssertEqual(result.reasons.count, 2)
        
        result.reasons.forEach { reason in
            guard case let .invalidValue(keyPath) = reason else { XCTFail("Not valid reason"); return }
            XCTAssertTrue(invalidErrors.keys.contains(keyPath))
        }
    }
    
    func testValid() {
        let partial = User(firstName: "Test", lastName: "Test 123", age: 18).partial()
       
        let validation = Partial<User>.Validation(
            .required(\User.firstName),
            .valueValidation(keyPath: \User.firstName, block: { !$0.isEmpty }),
            .required(\User.lastName),
            .valueValidation(keyPath: \User.lastName, block: { $0.count > 5 }),
            .valueValidation(keyPath: \User.age, block: { $0! >= 18 })
        )
        
        let result = validation.validate(partial)
        
        guard case .valid = result else { XCTFail("Not valid"); return }
        XCTAssert(true)
    }

}
