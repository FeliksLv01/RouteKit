/// Accumulates route registrations before building an immutable `RouteTrie`.
struct RouteTrieBuilder<Output: Sendable> {
    typealias Node = RouteTrieNode<Output>

    let config: RouteTrie<Output>.Configuration

    var root: Node

    init(
        _ type: Output.Type = Output.self,
        config: RouteTrie<Output>.Configuration = .init()
    ) {
        self.root = Node()
        self.config = config
    }

    func build() -> RouteTrie<Output> {
        .init(builder: self)
    }

    mutating func register(_ output: Output, at path: [RoutePathComponent]) {
        assert(!path.isEmpty, "Cannot register a route with an empty path.")
        root = insertRoute(node: root, path: path[...], output: output)
    }

    private func insertRoute(node: Node, path: ArraySlice<RoutePathComponent>, output: Output) -> Node {
        guard let component = path.first else {
            return node.copyWith(output: output)
        }

        let isCaseInsensitive = config.isCaseInsensitive
        switch component {
        case .constant(let string):
            let key = isCaseInsensitive ? string.lowercased() : string
            var constants = node.constants
            let child = constants[key] ?? Node()
            constants[key] = insertRoute(node: child, path: path.dropFirst(), output: output)
            return node.copyWith(constants: constants)
        case .parameter(let name):
            let wildcard = node.wildcard
            let child: Node
            if let existing = wildcard {
                if let existingName = existing.parameter {
                    precondition(
                        existingName == name,
                        "It is not possible to have two routes with the same prefix but different parameter names, even if the trailing path components differ (tried to add route with \(name) that collides with \(existingName))."
                    )
                }
                child = existing.node
            } else {
                child = Node()
            }
            let newWildcard = Node.Wildcard(
                node: insertRoute(node: child, path: path.dropFirst(), output: output), parameter: name,
                explicitlyIncludesAnything: wildcard?.explicitlyIncludesAnything ?? false
            )
            return node.copyWith(wildcard: newWildcard)
        case .catchall:
            precondition(path.count == 1, "Catchall must be the last component in a path.")
            let newCatchall = insertRoute(node: node.catchall ?? Node(), path: path.dropFirst(), output: output)
            return node.copyWith(catchall: newCatchall)
        case .anything:
            let child: Node
            if let wildcard = node.wildcard {
                child = wildcard.node
            } else {
                child = Node()
            }
            let newWildcard = Node.Wildcard(
                node: insertRoute(node: child, path: path.dropFirst(), output: output),
                parameter: node.wildcard?.parameter,
                explicitlyIncludesAnything: true
            )
            return node.copyWith(wildcard: newWildcard)
        case .partialParameter(let template, let components, let parameters):
            precondition(
                parameters.count == Set(parameters).count, #"Partial ":\#(template)" contains multiple parameters with the same name"#
            )
            var partials = node.partials ?? []
            let child = partials.first(where: { $0.template == template })?.node ?? Node()
            let updatedChild = insertRoute(node: child, path: path.dropFirst(), output: output)
            partials.append(.init(template: template, components: components, parameters: parameters, node: updatedChild))
            // Query more specific partials first: `file.{ext}` should beat `{name}.{ext}`.
            partials.sort { $0.ambiguity < $1.ambiguity }
            return node.copyWith(partials: partials)
        }
    }
}

extension RouteTrieNode.PartialMatch {
    var ambiguity: Int {
        self.parameters.count
    }
}
