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

struct Functions {
	
	/// Function that retrieves the current weather for a given location.
	/// - Parameters:
	///  - location: The location for which to get the weather.
	@openAIFunction
	func getCurrentWeather(location: String, unit: String = "celsius") -> String {
		""
	}
}

extension AnyJSONSchema {

	public static func forType(_ type: Any.Type) throws -> AnyJSONSchema {
		// Basic type mapping
		if type == String.self {
			return AnyJSONSchema(fields: [.type(.string)])
		} else if type == Int.self || type == Int32.self || type == Int64.self {
			return AnyJSONSchema(fields: [.type(.integer)])
		} else if type == Double.self || type == Float.self {
			return AnyJSONSchema(fields: [.type(.number)])
		} else if type == Bool.self {
			return AnyJSONSchema(fields: [.type(.boolean)])
		} else if let caseIterable = type as? any CaseIterable.Type {
			// Handle enums that conform to both CaseIterable and RawRepresentable
			let values = caseIterable.allCases.compactMap { case_ in
				(case_ as? any RawRepresentable)?.rawValue as? any JSONDocument
			}
			let enumValues = values.map { AnyJSONDocument($0) }
			return AnyJSONSchema(fields: [
				.type(.string),
				.enumValues(enumValues)
			])
		} else if type is any JSONDocument.Type {
			fatalError("not implemented yet")
		} else if type is any Collection.Type {
			fatalError("not implemented yet")
		} else if type is any Codable.Type {
			// Handle custom Codable types as objects
			return AnyJSONSchema(fields: [.type(.object)])
		} else {
			// Default to string for unknown types
			return AnyJSONSchema(fields: [.type(.string)])
		}
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
