public protocol Requestable: Sendable { }

extension Array: Requestable where Element: Requestable { }
