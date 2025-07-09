import XCTest
import OpenAI
import OpenAIMacros

final class OpenAIMacrosTests: XCTestCase {

	func testChat() async throws {
		do {
			let openAI = OpenAI(apiToken: "")
			
			let result = try await openAI.chatsWith(
				functions: [Functions().getCurrentWeatherCall],
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

struct Functions {

	/// Function that retrieves the current weather for a given location.
	/// - Parameters:
	///  - location: The location for which to get the weather.
	@openAIFunction
	func getCurrentWeather(location: String, unit: TemperatureUnit = .celsius) async throws -> GetWeatherResponse {
		GetWeatherResponse(temperature: 23, unit: unit)
	}
}

enum TemperatureUnit: String, CaseIterable, Codable {
	case celsius
	case fahrenheit
}

struct GetWeatherResponse: Codable {
	let temperature: Double
	let unit: TemperatureUnit
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
		Functions().getCurrentWeatherCall // just placeholder for now
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
			throw NSError(
				domain: "OpenAIMacrosTests",
				code: 1,
				userInfo: [NSLocalizedDescriptionKey: "Unexpected result from chat query"]
			)
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
