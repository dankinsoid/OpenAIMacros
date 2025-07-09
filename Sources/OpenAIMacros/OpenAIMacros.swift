import OpenAI

/// A macro that generates OpenAI function declarations from Swift function definitions.
///
/// Usage:
/// ```swift
/// @openAIFunction
/// func getCurrentWeather(location: String, unit: String = "celsius") -> String {
///     // Implementation
/// }
/// ```
///
/// This will generate the corresponding `FunctionDeclaration` for use with OpenAI's function calling API.
@attached(peer, names: arbitrary)
public macro openAIFunction() = #externalMacro(module: "OpenAIMacrosMacros", type: "OpenAIFunctionMacro")

/// Convenience extensions for working with OpenAI function calls
extension OpenAI {
    // TODO: Add helper methods for easier function calling integration
}
