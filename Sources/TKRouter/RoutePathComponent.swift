/// One parsed component from a route registration pattern.
enum RoutePathComponent: ExpressibleByStringInterpolation, CustomStringConvertible, Sendable, Hashable {
    case constant(String)

    case parameter(String)

    case partialParameter(template: String, components: [Substring], parameters: [Substring])

    case anything

    case catchall

    init(stringLiteral value: String) {
        if value.starts(with: ":") && value.firstIndex(of: "{") != nil {
            var components: [Substring] = []
            var parameters: [Substring] = []

            var inBraces = false

            for index in value.indices.dropFirst() {
                let char = value[index]
                switch char {
                case "{":
                    inBraces = true
                    parameters.append("")
                    components.append("")
                case "}":
                    inBraces = false
                    if value.index(after: index) < value.endIndex { components.append("") }
                default:
                    if inBraces {
                        if parameters.isEmpty { parameters.append(.init()) }
                        parameters[parameters.index(before: parameters.endIndex)].append(char)
                    } else {
                        if components.isEmpty { components.append(.init()) }
                        components[components.index(before: components.endIndex)].append(char)
                    }
                }
            }
            if inBraces { preconditionFailure("Unclosed '{' in path component literal: \(value)") }
            self = .partialParameter(template: .init(value.dropFirst()), components: components, parameters: parameters)
        } else if value.starts(with: ":") {
            self = .parameter(.init(value.dropFirst()))
        } else if value == "*" {
            self = .anything
        } else if value == "**" {
            self = .catchall
        } else {
            self = .constant(value)
        }
    }

    var description: String {
        switch self {
        case .anything: "*"
        case .catchall: "**"
        case .parameter(let name): ":" + name
        case .constant(let constant): constant
        case .partialParameter(let template, _, _): template
        }
    }
}
