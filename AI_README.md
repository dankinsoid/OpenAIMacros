# AI README - OpenAI Macros Project

## Project Vision

This Swift package provides macros to eliminate boilerplate when using OpenAI's function calling API. Instead of manually creating `FunctionDeclaration` structs, developers annotate Swift functions with `@openAIFunction` and let macros generate everything.

## Architecture Overview

### Core Components

1. **OpenAIFunctionWrapper** - Bridge between OpenAI API and Swift functions
   - `difinition`: OpenAI's `FunctionDefinition` (JSON schema)
   - `execution`: Closure that decodes JSON params → executes Swift function → encodes result

2. **OpenAI.chatsWith extension** - Complete function calling workflow
   - Sends query with functions to OpenAI
   - Processes tool calls from response
   - Executes corresponding Swift functions
   - Continues conversation with results
   - Handles recursive function calling

### Macro Targets

#### @OpenAIFunction
Applied to Swift functions, generates:
- Parameter struct (e.g., `GetWeatherParameters`) 
- `OpenAIFunctionWrapper` with proper JSON schema
- Execution closure bridging JSON ↔ Swift
- Automatic type mapping (String → .string, enum → .enumValues, etc.)

#### @OpenAIFunctionsCollection  
Applied to structs/classes, generates:
- `allFunctions: [OpenAIFunctionWrapper]` array
- Convenience chat methods for direct interaction
- Example: `getWeather("What's weather in Boston?")` → full OpenAI conversation

## Implementation Strategy

### Phase 1: Basic @OpenAIFunction
- Parse function signature with SwiftSyntax
- Generate parameter struct from function parameters
- Create JSON schema from Swift types
- Generate wrapper with execution closure

### Phase 2: Advanced Features
- Doc comment → function description
- Default parameters → optional/required mapping
- Enum parameters → enumValues in schema
- Complex return types → structured responses

### Phase 3: @OpenAIFunctionsCollection
- Scan struct/class for @OpenAIFunction methods
- Generate allFunctions array
- Create convenience chat methods
- Handle OpenAI client integration

## Key Files

- `/Sources/OpenAIMacrosMacros/OpenAIMacrosMacros.swift` - Macro implementations
- `/Sources/OpenAIMacros/OpenAIMacros.swift` - Public API and macro declarations
- `/Tests/OpenAIMacrosTests/OpenAIMacrosTests.swift` - **Contains working proof of concept**

## Proof of Concept (in Tests)

The test file contains a fully working example showing:
- Manual `OpenAIFunctionWrapper` creation (what macro will generate)
- Complete `chatsWith` workflow implementation
- Two different usage patterns (`Functions` vs `Functions1`)
- Proper error handling and async/await support

## Technical Notes

- Uses MacPaw's OpenAI Swift library
- Requires Swift 5.9+ for macro support
- JSON schema generation from Swift types is straightforward
- Runtime execution works via closures with proper capture
- Error handling includes custom types for function calling failures

## Future Claude Sessions

When working on this project:
1. The proof of concept in tests shows the complete working system
2. Focus on macro generation of the boilerplate shown in `Functions` struct
3. The `chatsWith` extension is the key innovation for seamless function calling
4. `OpenAIFunctionWrapper` is the bridge between OpenAI API and Swift functions