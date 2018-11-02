# FormValidation
## KeyPath-based Form Validation
Easy to use validation based on type-safe KVC in Swift

##### Define Partial Type
```swift
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
```

##### Validation nested type with strategies
```swift
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
```

##### Validation Result
```swift
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
```

##### Validation Strategy
```swift
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
```

## How to use
##### 1. Create Model Object
```swift
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

let partial = User(firstName: "foo", lastName: "bar", age: nil).partial()
```

##### 2. Define Validation Rules
```swift
let validation = Partial<User>.Validation(
    .required(\User.firstName),
    .valueValidation(keyPath: \User.firstName, block: { !$0.isEmpty }),
    .required(\User.lastName),
    .valueValidation(keyPath: \User.lastName, block: { $0.count > 5 }),
    .valueValidation(keyPath: \User.age, block: { ($0 ?? 0) >= 18 }),
    .required(\User.age)
)

let missingErrors: [PartialKeyPath<User>: String] = [
    \User.firstName: "Missed first name",
    \User.lastName: "Missed last name"
]

let invalidErrors: [PartialKeyPath<User>: String] = [
    \User.lastName: "LastName should containts more than 5 symbols",
    \User.age: "Age should be more than 18"
]
```

##### 3. Perform Validation
```swift
switch validation.validate(partial) {
case .valid(let result):
    print(result)
    do {
        let user = try User(from: partial)
    } catch { print(error) }
case .invalid(let reasons):
    reasons.forEach {
        switch $0 {
        case .missing(let keyPath):
            if missingErrors.keys.contains(keyPath) { print(missingErrors[keyPath]) }
        case .invalidValue(let keyPath):
            if invalidErrors.keys.contains(keyPath) { print(invalidErrors[keyPath]) }
        }
    }
}
```
