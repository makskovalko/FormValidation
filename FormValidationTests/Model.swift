//
//  Model.swift
//  FormValidation
//
//  Created by Maxim Kovalko on 11/2/18.
//  Copyright © 2018 Maxim Kovalko. All rights reserved.
//
import FormValidation

struct User: PartialInitializable {
    let firstName: String
    let lastName: String
    let age: Int?
    
    init(firstName: String, lastName: String, age: Int?) {
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
    }
    
    func partial() -> Partial<User> {
        var partial = Partial<User>()
        partial.update(\.firstName, to: firstName)
        partial.update(\.lastName, to: lastName)
        partial.update(\.age, to: age)
        return partial
    }
}

extension User {
    init(from partial: Partial<User>) throws {
        firstName = try partial.value(for: \.firstName)
        lastName = try partial.value(for: \.lastName)
        age = partial.value(for: \.age)
    }
}
