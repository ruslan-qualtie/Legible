import Nimble

public func shouldNotBeCalled<T>(_ value: T, file: FileString = #file, line: UInt = #line) {
    fail("should not be called, but got \(value)", file: file, line: line)
}

public func shouldNotBeCalled<T>(_ value: T) {
    fail("should not be called, but got \(value)")
}
