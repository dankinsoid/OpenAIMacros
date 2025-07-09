import OpenAI
import Foundation

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

extension AnyJSONSchema {

	public static func forType(_ type: Any.Type) throws -> AnyJSONSchema {
		fatalError("Not implemented")
//		if let caseIterable = type as? any CaseIterable.Type,
//		   let rawRepresentable = type as? any RawRepresentable.Type,
//		   let firstCase = caseIterable.allCases.first {
//			let values = caseIterable.allCases.compactMap({ $0 as? any RawRepresentable })
//			return AnyJSONSchema(
//				fields: [
////					.type(AnyJSONSchema.forType(rawRepresentable.RawValue.self))
//					.enumValues(values.map { AnyJSONDocument.init(<#T##value: any JSONDocument##any JSONDocument#>) })
//				]
//				
//			)
//		}
	}
}

/// Wrapper for OpenAI function calls (from the proof of concept)
public struct OpenAIFunctionWrapper {

    public let difinition: ChatQuery.ChatCompletionToolParam.FunctionDefinition
    public let execution: (JSONDecoder, Data, JSONEncoder) async throws -> Data
    
    public init(
        difinition: ChatQuery.ChatCompletionToolParam.FunctionDefinition,
        execution: @escaping (JSONDecoder, Data, JSONEncoder) async throws -> Data
    ) {
        self.difinition = difinition
        self.execution = execution
    }
}
