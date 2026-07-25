import Foundation

/// Internal trie used by `RouterRuntime` to resolve registered route patterns.
final class RouteTrie<Output: Sendable>: Sendable, CustomStringConvertible {
    typealias Node = RouteTrieNode<Output>

    struct Configuration: Sendable {
        let isCaseInsensitive: Bool

        init(isCaseInsensitive: Bool = false) {
            self.isCaseInsensitive = isCaseInsensitive
        }
    }

    let root: Node

    let config: Configuration

    init(builder: RouteTrieBuilder<Output>) {
        self.root = builder.root
        self.config = builder.config
    }

    func route(path: [String], parameters: inout RouteMatchParameters) -> Output? {
        route(path: path, from: path.startIndex, parameters: &parameters, root: self.root, isCaseInsensitive: self.config.isCaseInsensitive)
    }

    struct Alternative {
        enum Kind {
            case wildcard(String, Node.Wildcard)
            case partial(Node.PartialMatch)
        }

        let node: Node
        let index: Int
        let kind: Kind
        let parameterSnapshot: RouteMatchParameters
    }

    func route(
        path: [String], from startIndex: Int, parameters: inout RouteMatchParameters, root: Node, isCaseInsensitive: Bool
    ) -> Output? {
        var currentNode = root
        var currentCatchall: (Node, [String])?
        var alternatives: [Alternative] = []

        search: for index in path.indices[startIndex...] {
            let slice = path[index]
            if let catchall = currentNode.catchall {
                currentCatchall = (catchall, [String](path.dropFirst(index)))
            }

            if let constant = currentNode.constants[isCaseInsensitive ? slice.lowercased() : slice] {
                if let wildcard = currentNode.wildcard {
                    alternatives.append(
                        .init(
                            node: wildcard.node,
                            index: index,
                            kind: .wildcard(slice, wildcard),
                            parameterSnapshot: parameters
                        )
                    )
                }

                alternatives.append(
                    contentsOf: currentNode.partials?.map {
                        .init(node: $0.node, index: index, kind: .partial($0), parameterSnapshot: parameters)
                    } ?? []
                )

                currentNode = constant
                continue search
            }

            if let wildcard = currentNode.wildcard {
                alternatives.append(
                    contentsOf: currentNode.partials?.map {
                        .init(node: $0.node, index: index, kind: .partial($0), parameterSnapshot: parameters)
                    } ?? [])

                if let name = wildcard.parameter {
                    parameters.set(name, to: slice)
                }

                currentNode = wildcard.node
                continue search
            }

            if let partials = currentNode.partials, !partials.isEmpty {
                for partial in partials {
                    if let captures = isMatchForPartial(partial: partial, path: slice, parameters: parameters) {
                        for (name, value) in captures {
                            parameters.set(String(name), to: String(value))
                        }
                        currentNode = partial.node
                        continue search
                    }
                }
            }

            if let (catchall, subpaths) = currentCatchall {
                parameters.setCatchall(matched: subpaths)
                return catchall.output
            } else {
                return tryAlternatives(
                    path: path,
                    alternatives: alternatives,
                    currentCatchall: currentCatchall,
                    isCaseInsensitive: isCaseInsensitive,
                    parameters: &parameters
                )
            }
        }

        if let output = currentNode.output {
            return output
        } else if let (catchall, subpaths) = currentCatchall {
            parameters.setCatchall(matched: subpaths)
            return catchall.output
        } else if path.isEmpty, let catchall = currentNode.catchall {
            parameters.setCatchall(matched: [])
            return catchall.output
        } else if let result = tryAlternatives(
            path: path,
            alternatives: alternatives,
            currentCatchall: currentCatchall,
            isCaseInsensitive: isCaseInsensitive,
            parameters: &parameters
        ) {
            return result
        } else {
            return nil
        }
    }

    func tryAlternatives(
        path: [String],
        alternatives: [Alternative],
        currentCatchall: (Node, [String])?,
        isCaseInsensitive: Bool,
        parameters: inout RouteMatchParameters
    ) -> Output? {
        for alternative in alternatives.reversed() {
            var altParameters = alternative.parameterSnapshot
            switch alternative.kind {
            case .wildcard(let slice, let wildcard):
                if let name = wildcard.parameter {
                    altParameters.set(name, to: slice)
                }

                if let output = route(
                    path: path,
                    from: alternative.index + 1,
                    parameters: &altParameters,
                    root: alternative.node,
                    isCaseInsensitive: isCaseInsensitive
                ) {
                    parameters = altParameters
                    return output
                }
            case .partial(let partial):
                let slice = path[alternative.index]
                if let captures = isMatchForPartial(partial: partial, path: slice, parameters: altParameters) {
                    for (name, value) in captures {
                        altParameters.set(String(name), to: String(value))
                    }

                    if let output = route(
                        path: path,
                        from: alternative.index + 1,
                        parameters: &altParameters,
                        root: alternative.node,
                        isCaseInsensitive: isCaseInsensitive
                    ) {
                        parameters = altParameters
                        return output
                    }
                }
            }
        }

        if let (catchall, subpaths) = currentCatchall {
            parameters.setCatchall(matched: subpaths)
            return catchall.output
        }

        return nil
    }

    // See `CustomStringConvertible.description`.
    var description: String {
        self.root.description
    }

    func isMatchForPartial(partial: Node.PartialMatch, path: String, parameters: RouteMatchParameters) -> [Substring: Substring]? {
        var result: [Substring: Substring] = [:]
        var index = path.startIndex

        var componentIndex = partial.components.startIndex
        let lastComponentIndex = partial.components.index(before: partial.components.endIndex)

        while componentIndex <= lastComponentIndex {
            if index >= path.endIndex {
                // If we're at the end but there are more components, fail
                if componentIndex < lastComponentIndex { return nil }
                break
            }

            let element = partial.components[componentIndex]

            if element.isEmpty {
                let endIndex: String.Index
                if componentIndex < lastComponentIndex {
                    let nextElement = partial.components[partial.components.index(after: componentIndex)]
                    // Prefer the longest capture before the next literal component.
                    guard let range = path.range(of: nextElement, options: .backwards, range: index..<path.endIndex) else { return nil }
                    endIndex = range.lowerBound
                } else {
                    endIndex = path.endIndex
                }
                result[partial.parameters[result.count]] = path[index..<endIndex]
                index = endIndex
            } else {
                let substring = path[index...].prefix(element.count)
                guard substring == element else { return nil }
                index = substring.endIndex
            }

            partial.components.formIndex(after: &componentIndex)
        }

        return result
    }
}
