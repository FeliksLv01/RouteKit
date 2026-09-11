import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct RouteMacro: MemberMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    let routeType = try routeType(from: declaration)
    let patterns = try routePatterns(from: node)
    var members: [DeclSyntax] = []

    if routeType.isClass, !hasInitializer(in: declaration) {
      members.append("required init() {}")
    }

    if let patterns {
      guard !hasRegisterMethod(in: declaration) else {
        throw RouteMacroError.registerAlreadyDeclared
      }

      let calls = patterns.map { pattern in
        if pattern.priority == "default" {
          return "register(\(pattern.expression))"
        }
        return "register(\(pattern.expression), priority: .\(pattern.priority))"
      }
      members.append(
        DeclSyntax(
          stringLiteral: """
            static func register() {
                \(calls.joined(separator: "\n    "))
            }
            """
        )
      )
    }

    members.append(
      """
      @section("__DATA_CONST,__routekit")
      @used
      private static let _routekit_route_item: @convention(c) () -> UnsafeRawPointer = {
          unsafeBitCast(\(raw: routeType.name).self, to: UnsafeRawPointer.self)
      }

      private static let _routekit_route_type_check: any RouteHandler.Type = \(raw: routeType.name).self
      """
    )

    return members
  }

  private static func routeType(from declaration: some DeclGroupSyntax) throws -> (
    name: String, isClass: Bool
  ) {
    if let classDeclaration = declaration.as(ClassDeclSyntax.self) {
      return (classDeclaration.name.text, true)
    }
    if let structDeclaration = declaration.as(StructDeclSyntax.self) {
      return (structDeclaration.name.text, false)
    }
    throw RouteMacroError.notRouteType
  }

  private static func routePatterns(from node: AttributeSyntax) throws -> [(
    expression: String, priority: String
  )]? {
    guard let arguments = node.arguments else {
      return nil
    }
    guard case .argumentList(let argumentList) = arguments,
      argumentList.count == 1,
      let patternsArgument = argumentList.first,
      patternsArgument.label?.text == "patterns",
      let array = patternsArgument.expression.as(ArrayExprSyntax.self)
    else {
      throw RouteMacroError.invalidArguments
    }

    return try array.elements.map { element in
      guard let call = element.expression.as(FunctionCallExprSyntax.self),
        isInitCall(call.calledExpression),
        let patternArgument = call.arguments.first,
        patternArgument.label == nil
      else {
        throw RouteMacroError.invalidPattern
      }

      let unexpectedArgument = call.arguments.dropFirst().first {
        $0.label?.text != "priority"
      }
      guard unexpectedArgument == nil,
        call.arguments.filter({ $0.label?.text == "priority" }).count <= 1
      else {
        throw RouteMacroError.invalidPattern
      }

      let priority: String
      if let priorityExpression = call.arguments.first(where: { $0.label?.text == "priority" })?
        .expression
      {
        guard let memberAccess = priorityExpression.as(MemberAccessExprSyntax.self) else {
          throw RouteMacroError.invalidPriority
        }
        priority = memberAccess.declName.baseName.text
        guard ["low", "default", "high"].contains(priority) else {
          throw RouteMacroError.invalidPriority
        }
      } else {
        priority = "default"
      }

      return (patternArgument.expression.trimmedDescription, priority)
    }
  }

  private static func isInitCall(_ expression: ExprSyntax) -> Bool {
    guard let memberAccess = expression.as(MemberAccessExprSyntax.self) else {
      return false
    }
    return memberAccess.declName.baseName.text == "init"
  }

  private static func hasInitializer(in declaration: some DeclGroupSyntax) -> Bool {
    declaration.memberBlock.members.contains { member in
      member.decl.is(InitializerDeclSyntax.self)
    }
  }

  private static func hasRegisterMethod(in declaration: some DeclGroupSyntax) -> Bool {
    declaration.memberBlock.members.contains { member in
      guard let function = member.decl.as(FunctionDeclSyntax.self) else {
        return false
      }
      return function.name.text == "register"
        && function.signature.parameterClause.parameters.isEmpty
    }
  }
}

enum RouteMacroError: Error, CustomStringConvertible {
  case invalidArguments
  case invalidPattern
  case invalidPriority
  case notRouteType
  case registerAlreadyDeclared

  var description: String {
    switch self {
    case .invalidArguments:
      return "@Route expects a 'patterns' array."
    case .invalidPattern:
      return "@Route patterns must use '.init(\"pattern\", priority: .default)'."
    case .invalidPriority:
      return "@Route priority must be .low, .default, or .high."
    case .notRouteType:
      return "@Route can only be applied to a class or struct."
    case .registerAlreadyDeclared:
      return
        "@Route cannot generate register() because the type already declares it. Use @Route without arguments for custom registration."
    }
  }
}
