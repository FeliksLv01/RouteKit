/// Node in the internal route trie.
final class RouteTrieNode<Output: Sendable>: Sendable, CustomStringConvertible {
    struct Wildcard: Sendable {
        let parameter: String?

        let explicitlyIncludesAnything: Bool

        let node: RouteTrieNode

        init(node: RouteTrieNode, parameter: String? = nil, explicitlyIncludesAnything: Bool = false) {
            self.node = node
            self.parameter = parameter
            self.explicitlyIncludesAnything = explicitlyIncludesAnything
        }
    }

    struct PartialMatch: Sendable {
        let template: String

        let components: [Substring]

        let parameters: [Substring]

        let node: RouteTrieNode
    }

    let constants: [String: RouteTrieNode]

    let wildcard: Wildcard?

    let partials: [PartialMatch]?

    let catchall: RouteTrieNode?

    let output: Output?

    init(
        output: Output? = nil,
        constants: [String: RouteTrieNode] = [:],
        wildcard: Wildcard? = nil,
        catchall: RouteTrieNode? = nil,
        partials: [PartialMatch]? = nil
    ) {
        self.output = output
        self.constants = constants
        self.wildcard = wildcard
        self.catchall = catchall
        self.partials = partials
    }

    var description: String {
        self.subpathDescriptions.joined(separator: "\n")
    }

    var subpathDescriptions: [String] {
        var desc: [String] = []
        for (name, constant) in self.constants {
            desc.append("→ \(name)")
            desc += constant.subpathDescriptions.indented()
        }

        if let wildcard = self.wildcard {
            if let name = wildcard.parameter {
                desc.append("→ :\(name)")
                desc += wildcard.node.subpathDescriptions.indented()
            }

            if wildcard.explicitlyIncludesAnything {
                desc.append("→ *")
                desc += wildcard.node.subpathDescriptions.indented()
            }
        }

        for partial in self.partials ?? [] {
            desc.append("→ \(partial.template)")
            desc += partial.node.subpathDescriptions.indented()
        }

        if self.catchall != nil {
            desc.append("→ **")
        }
        return desc
    }

    func copyWith(
        output: Output? = nil,
        constants: [String: RouteTrieNode]? = nil,
        wildcard: Wildcard? = nil,
        catchall: RouteTrieNode? = nil,
        partials: [PartialMatch]? = nil
    ) -> RouteTrieNode {
        RouteTrieNode(
            output: output ?? self.output,
            constants: constants ?? self.constants,
            wildcard: wildcard ?? self.wildcard,
            catchall: catchall ?? self.catchall,
            partials: partials ?? self.partials
        )
    }
}

extension Array where Element == String {
    fileprivate func indented() -> [String] {
        self.map { "  " + $0 }
    }
}
