import XCTest
import OpenAI

final class OpenAIMacrosTests: XCTestCase {

	func testChat() async throws {
		do {
			let openAI = OpenAI(apiToken: "")
			
			let result = try await openAI.chatsWith(
				functions: [Functions().getWeatherCall],
				query: ChatQuery(messages: [.user(.init(content: .string("What's the weather like in Boston?")))], model: "gpt-4o")
			).choices[0].message.content!
			
			print(result)
		} catch {
			XCTFail("Chat query failed with error: \(error)")
		}
	}

    func testMacro() throws {
        #if canImport(OpenAIMacrosMacros)
        // TODO: Add comprehensive tests for the OpenAI function macro
        // This will test the generation of FunctionDeclaration from Swift functions
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}

extension OpenAI {

	func chatsWith(
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

struct UnknownFunctionCall: Error, LocalizedError {
	let functionName: String
}

struct InvalidString: Error, LocalizedError {
	let message: String
}

struct Functions {
	
	// macro generated (@OpenAIFunction)
	var getWeatherCall: OpenAIFunctionWrapper {
		OpenAIFunctionWrapper(
			difinition: ChatQuery.ChatCompletionToolParam.FunctionDefinition(
				name: "get_current_weather",
				description: "Get the current weather in a given location",
				parameters: .init(fields: [
					.type(.object),
					.properties([
						"location": .init(fields: [
							.type(.string),
							.description("The city and state, e.g. San Francisco, CA")
						]),
						"unit": .init(fields: [
							.type(.string),
							.enumValues(["celsius", "fahrenheit"])
						])
					]),
					.required(["location"])
				])
			)
		) { [self] decoder, data, encoder in
			let parameters = try decoder.decode(GetWeatherParameters.self, from: data)
			let result = getWeather(
				location: parameters.location,
				unit: parameters.unit
			)
			return try encoder.encode(result)
		}
	}
	
	// macro generated (@OpenAIFunction)
	struct GetWeatherParameters: Codable, Hashable, Sendable {
		let location: String
		let unit: TemperatureUnit?
	}

	/// Get the current weather in a given location
	///
	/// - Parameters:
	///  - location: The city and state, e.g. San Francisco, CA
	// @OpenAIFunction
	func getWeather(location: String, unit: TemperatureUnit? = nil) -> GetWeatherResponse {
		GetWeatherResponse(temperature: 23, unit: unit ?? .celsius)
	}
}

// macro @OpenAIFunctionsCollection
struct Functions1 {
	
	let openAI: OpenAI
	let query: ChatQuery // default query
	
	// macro generated (@OpenAIFunctionsCollection)
	var allFunctions: [OpenAIFunctionWrapper] {
		[getWeatherCall]
	}
	
	// macro generated (@OpenAIFunction)
	var getWeatherCall: OpenAIFunctionWrapper {
		Functions().getWeatherCall // just placeholder for now
	}

	// macro generated (@OpenAIFunctionsCollection)
	/// Get the current weather in a given location
	func getWeather(_ message: String) async throws -> String {
		let result = try await openAI.chatsWith(
			functions: allFunctions,
			query: ChatQuery(
				messages: query.messages + [.user(.init(content: .string(message)))],
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
		guard result.choices.count == 1, let string = result.choices[0].message.content else {
			throw ExtectedSingleStringResponse(response: result)
		}
		return string
	}

	/// Get the current weather in a given location
	///
	/// - Parameters:
	///  - location: The city and state, e.g. San Francisco, CA
	// @OpenAIFunction
	func getWeather(location: String, unit: TemperatureUnit? = nil) -> GetWeatherResponse {
		GetWeatherResponse(temperature: 23, unit: unit ?? .celsius)
	}
}

struct OpenAIFunctionWrapper {
	
	let difinition: ChatQuery.ChatCompletionToolParam.FunctionDefinition
	let execution: (JSONDecoder, Data, JSONEncoder) async throws -> Data
}

struct ExtectedSingleStringResponse: Error {
	
	let response: ChatResult
}

struct GetWeatherResponse: Codable, Hashable, Sendable {
	let temperature: Double
	let unit: TemperatureUnit
}
	
enum TemperatureUnit: String, Codable, Hashable, CaseIterable {
	
	case celsius
	case fahrenheit
}
