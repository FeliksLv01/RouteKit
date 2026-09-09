import Foundation

public protocol URLConvertible {
    var urlValue: URL? { get }
}

extension String: URLConvertible {
    public var urlValue: URL? { URL(string: self) }
}

extension URL: URLConvertible {
    public var urlValue: URL? { self }
}
