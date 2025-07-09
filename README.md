# OpenAI Macros

A Swift package that provides macros for seamless integration with OpenAI's function calling API. Instead of manually creating `FunctionDeclaration` structs, simply annotate your Swift functions with `@openAIFunction` and let the macro generate the boilerplate.

## Installation

Add this package to your Swift project:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/OpenAIMacros", from: "1.0.0")
]
```

## Usage

### Before (Manual approach)
```swift
let functions = [
  FunctionDeclaration(
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
]
```

### After (With OpenAI Macros)
```swift
import OpenAIMacros

@openAIFunction
func getCurrentWeather(location: String, unit: String = "celsius") -> String {
    // Your implementation here
    return "Weather data for \(location)"
}
```

The macro automatically generates the corresponding `FunctionDeclaration` based on your function signature, parameter types, and documentation comments.

## Features

- **Automatic Function Declaration Generation**: Convert Swift functions to OpenAI function declarations
- **Type Safety**: Leverage Swift's type system for parameter validation
- **Documentation Integration**: Use Swift doc comments for function descriptions
- **Default Parameter Support**: Handle optional parameters and default values
- **Multiple Return Types**: Support for various return types including structured data

## Development Status

🚧 **This package is currently under development.** The macro implementation is a placeholder and will be completed soon.

## Requirements

- Swift 5.9+
- macOS 10.15+, iOS 13+, tvOS 13+, watchOS 6+

## License

MIT License - see LICENSE file for details.
