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

extension OpenAI {

    /// Enhanced chat method that automatically handles function calling workflow
    /// - Parameters:
    ///   - functions: Array of OpenAI function wrappers to make available
    ///   - query: The chat query to send
    /// - Returns: Chat result with function calls automatically executed
    public func chatsWith(
        functions: [OpenAIFunctionWrapper],
        query: ChatQuery
    ) async throws -> ChatResult {
        var messages = query.messages
        let tools = query.tools ?? [] + functions.map { .init(function: $0.difinition) }
        let query = ChatQuery(
            messages: messages,
            model: query.model,
            modalities: query.modalities,
            audioOptions: query.audioOptions,
            reasoningEffort: query.reasoningEffort,
            frequencyPenalty: query.frequencyPenalty,
            logitBias: query.logitBias,
            logprobs: query.logprobs,
            maxCompletionTokens: query.maxCompletionTokens,
            metadata: query.metadata,
            n: query.n,
            parallelToolCalls: query.parallelToolCalls,
            prediction: query.prediction,
            presencePenalty: query.presencePenalty,
            responseFormat: query.responseFormat,
            seed: query.seed,
            serviceTier: query.serviceTier,
            stop: query.stop,
            store: query.store,
            temperature: query.temperature,
            toolChoice: query.toolChoice,
            tools: tools,
            topLogprobs: query.topLogprobs,
            topP: query.topP,
            user: query.user,
            webSearchOptions: query.webSearchOptions,
            stream: query.stream,
            streamOptions: query.streamOptions
        )
        
        let result0 = try await chats(query: query)
        let calls = result0.choices.flatMap { $0.message.toolCalls ?? [] }
        
        guard !calls.isEmpty else {
            return result0
        }
        
        var outputParams: [String] = []
        
        let encoder = JSONEncoder()
        
        let dictionary: [String: OpenAIFunctionWrapper] = Dictionary(functions.map { ($0.difinition.name, $0) }) { _, rhs in rhs }

        for call in calls {
            guard let function = dictionary[call.function.name] else {
                throw UnknownFunctionCall(functionName: call.function.name)
            }
            guard let data = call.function.arguments.data(using: .utf8) else {
                throw InvalidString(message: "Invalid function call arguments for \(call.function.name)")
            }
            let outputData = try await function.execution(JSONDecoder(), data, encoder)
            guard let output = String(data: outputData, encoding: .utf8) else {
                throw InvalidString(message: "Failed to decode output for \(call.function.name)")
            }
            let param = Components.Schemas.FunctionCallOutputItemParam(
                callId: call.id,
                _type: .functionCallOutput,
                output: output
            )
            guard let jsonString = String(data: try encoder.encode(param), encoding: .utf8) else {
                throw InvalidString(message: "Failed to encode output for \(call.function.name)")
            }
            outputParams.append(jsonString)
        }
        
        guard !outputParams.isEmpty else {
            return result0
        }

        messages += outputParams.map { .user(.init(content: .string($0))) }

        return try await chatsWith(
            functions: functions,
            query: ChatQuery(
                messages: messages,
                model: query.model,
                modalities: query.modalities,
                audioOptions: query.audioOptions,
                reasoningEffort: query.reasoningEffort,
                frequencyPenalty: query.frequencyPenalty,
                logitBias: query.logitBias,
                logprobs: query.logprobs,
                maxCompletionTokens: query.maxCompletionTokens,
                metadata: query.metadata,
                n: query.n,
                parallelToolCalls: query.parallelToolCalls,
                prediction: query.prediction,
                presencePenalty: query.presencePenalty,
                responseFormat: query.responseFormat,
                seed: query.seed,
                serviceTier: query.serviceTier,
                stop: query.stop,
                store: query.store,
                temperature: query.temperature,
                toolChoice: query.toolChoice,
                tools: query.tools,
                topLogprobs: query.topLogprobs,
                topP: query.topP,
                user: query.user,
                webSearchOptions: query.webSearchOptions,
                stream: query.stream,
                streamOptions: query.streamOptions
            )
        )
    }
}

extension AnyJSONSchema {

	public static func forType(_ type: Any.Type) -> AnyJSONSchema {
		return forType(type, description: nil)
	}
	
	public static func forType(_ type: Any.Type, description: String?) -> AnyJSONSchema {
		var fields: [JSONSchemaField] = []
		
		// Basic type mapping
		if type == String.self {
			fields.append(.type(.string))
		} else if type == Int.self || type == Int32.self || type == Int64.self {
			fields.append(.type(.integer))
		} else if type == Double.self || type == Float.self {
			fields.append(.type(.number))
		} else if type == Bool.self {
			fields.append(.type(.boolean))
		} else if let caseIterable = type as? any CaseIterable.Type {
			// Handle enums that conform to both CaseIterable and RawRepresentable
			let values = caseIterable.allCases.compactMap { case_ in
				(case_ as? any RawRepresentable)?.rawValue as? any JSONDocument
			}
			let enumValues = values.map { AnyJSONDocument($0) }
			fields.append(.type(.string))
			fields.append(.enumValues(enumValues))
		} else if type is Dictionary<String, Any>.Type {
			// Handle dictionaries as JSON objects
			fields.append(.type(.object))
		} else if type is any Collection.Type {
			// Handle other collections as arrays
			fields.append(.type(.array))
		} else if type is any Codable.Type {
			// Handle custom Codable types as objects
			fields.append(.type(.object))
		} else {
			// Default to string for unknown types
			fields.append(.type(.string))
		}
		
		// Add description if provided
		if let description {
			fields.append(.description(description))
		}
		
		return AnyJSONSchema(fields: fields)
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

/// Error thrown when OpenAI tries to call a function that doesn't exist
public struct UnknownFunctionCall: Error, LocalizedError {
    public let functionName: String
    
    public init(functionName: String) {
        self.functionName = functionName
    }
    
    public var errorDescription: String? {
        return "Unknown function call: \(functionName)"
    }
}

/// Error thrown when string conversion fails during function calling
public struct InvalidString: Error, LocalizedError {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
    
    public var errorDescription: String? {
        return message
    }
}
