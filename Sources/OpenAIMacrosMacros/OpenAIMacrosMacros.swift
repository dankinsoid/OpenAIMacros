import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `@openAIFunction` macro.
public struct OpenAIFunctionMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // TODO: Implement macro that generates OpenAI function declarations
        // from Swift function definitions
        return []
    }
}

@main
struct OpenAIMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        OpenAIFunctionMacro.self,
    ]
}