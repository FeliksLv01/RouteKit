import Foundation

/// A value that can be converted into a URL for route resolution.
public protocol URLConvertible {
    /// The URL representation of this value, or `nil` when conversion fails.
    var urlValue: URL? { get }
}

extension String: URLConvertible {
    /// Creates a URL from the string.
    public var urlValue: URL? { URL(string: self) }
}

extension URL: URLConvertible {
    /// Returns this URL unchanged.
    public var urlValue: URL? { self }
}
