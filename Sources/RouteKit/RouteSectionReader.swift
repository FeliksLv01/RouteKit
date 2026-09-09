import Foundation
import MachO

enum RouteSectionReader {
    private typealias RouteItemGetter = @convention(c) () -> UnsafeRawPointer

    static func routeTypes() -> [any RouteHandler.Type] {
        var result: [ObjectIdentifier: any RouteHandler.Type] = [:]
        for imageIndex in 0..<_dyld_image_count() {
            guard let rawHeader = _dyld_get_image_header(imageIndex) else { continue }
            let header = UnsafePointer<mach_header_64>(OpaquePointer(rawHeader))
            for type in routeTypes(header: header) {
                result[ObjectIdentifier(type)] = type
            }
        }
        return result.values.sorted { String(reflecting: $0) < String(reflecting: $1) }
    }

    private static func routeTypes(header: UnsafePointer<mach_header_64>) -> [any RouteHandler.Type] {
        var size: UInt = 0
        guard let sectionData = getsectiondata(header, "__DATA_CONST", "__routekit", &size), size > 0 else { return [] }
        let itemSize = MemoryLayout<RouteItemGetter>.stride
        let count = Int(size) / itemSize
        let rawPointer = UnsafeRawPointer(sectionData)
        return (0..<count).compactMap { index in
            let getter = rawPointer.load(fromByteOffset: index * itemSize, as: RouteItemGetter.self)
            let metadata = getter()
            let type = unsafeBitCast(metadata, to: Any.Type.self)
            return type as? any RouteHandler.Type
        }
    }
}
