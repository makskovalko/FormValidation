//
//  FormValidation.swift
//  FormValidation
//
//  Created by Maxim Kovalko on 11/2/18.
//  Copyright © 2018 Maxim Kovalko. All rights reserved.
//

public protocol PartialInitializable {
    init(from partial: Partial<Self>) throws
    func partial() -> Partial<Self>
}

public struct Partial<T> where T: PartialInitializable {
    public enum Error: Swift.Error {
        case valueNotFound
    }
    
    public init() {}
    
    private var data: [PartialKeyPath<T>: Any] = [:]
    
    public mutating func update<U>(_ keyPath: KeyPath<T, U>, to newValue: U?) {
        data[keyPath] = newValue
    }
    
    public func value<U>(for keyPath: KeyPath<T, U>) throws -> U {
        guard let value = data[keyPath] as? U else { throw Error.valueNotFound }
        return value
    }
    
    public func value<U>(for keyPath: KeyPath<T, U?>) -> U? {
        return data[keyPath] as? U
    }
}

public extension Partial {
    public struct Validation {
        let validations: [Strategy]
        
        public init(_ strategies: Strategy...) { validations = strategies }
        
        public func validate(_ partial: Partial<T>) -> Result {
            let failureReasons: [Result.Reason] = validations.reduce([]) { result, strategy in
                switch strategy {
                case .required(let keyPath) where !partial.data.keys.contains(keyPath):
                    return result + [.missing(keyPath)]
                case .value(let validation) where !validation.isValid(partial: partial):
                    return result + [.invalidValue(validation.keyPath)]
                default: return result
                }
            }
            
            return failureReasons.isEmpty
                ? .valid(try! T(from: partial))
                : .invalid(failureReasons)
        }
    }
}

public extension Partial.Validation {
    public enum Result {
        case valid(T)
        case invalid([Reason])
        
        public var value: T? {
            guard case let .valid(value) = self else { return nil }
            return value
        }
        
        public var reasons: [Reason] {
            guard case let .invalid(reasons) = self else { return [] }
            return reasons
        }
    }
}

public extension Partial.Validation.Result {
    public enum Reason {
        case missing(PartialKeyPath<T>)
        case invalidValue(PartialKeyPath<T>)
    }
}

public extension Partial.Validation {
    public enum Strategy {
        case required(PartialKeyPath<T>)
        case value(AnyValidation)
        
        public static func valueValidation<V>(keyPath: KeyPath<T, V>,
                                       block: @escaping (V) -> Bool) -> Strategy {
            let validation = ValueValidation<V>(keyPath: keyPath, block)
            return .value(AnyValidation(validation))
        }
    }
}

public extension Partial.Validation {
    public struct ValueValidation<V> {
        let keyPath: KeyPath<T, V>
        let isValid: (V) -> Bool
        
        public init(keyPath: KeyPath<T, V>, _ isValid: @escaping (V) -> Bool) {
            self.keyPath = keyPath
            self.isValid = isValid
        }
    }
}

public extension Partial.Validation {
    public struct AnyValidation {
        let keyPath: PartialKeyPath<T>
        private let isValid: (Any) -> Bool
        
        public init<V>(_ base : ValueValidation<V>) {
            keyPath = base.keyPath
            isValid = {
                guard let value = $0 as? V else { return false }
                return base.isValid(value)
            }
        }
        
        public func isValid(partial: Partial<T>) -> Bool {
            guard let value = partial.data[keyPath] else { return false }
            return isValid(value)
        }
    }
}
