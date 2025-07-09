import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `@openAIFunction` macro.
public struct OpenAIFunctionMacro: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.notAFunction
        }

        let functionName = funcDecl.name.text
        let parameters = funcDecl.signature.parameterClause.parameters
        let docComment = extractDocComment(from: funcDecl)

        // Generate parameter struct
        let parameterStruct = try generateParameterStruct(
            functionName: functionName,
            parameters: parameters,
            docComment: docComment
        )

        // Generate OpenAIFunctionWrapper variable
        let wrapperVariable = try generateWrapperVariable(
            functionDecl: funcDecl,
            functionName: functionName,
            parameters: parameters,
            docComment: docComment
        )

        return [
            DeclSyntax(parameterStruct),
            DeclSyntax(wrapperVariable),
        ]
    }

    private static func extractDocComment(from funcDecl: FunctionDeclSyntax) -> String? {
        // Extract all doc comment lines from leading trivia
        var docCommentLines: [String] = []
        
        for trivia in funcDecl.leadingTrivia {
            if case let .docLineComment(comment) = trivia {
                docCommentLines.append(comment)
            }
            if case let .docBlockComment(comment) = trivia {
                docCommentLines.append(comment)
            }
        }
        
        if docCommentLines.isEmpty {
            return nil
        }
        
        // Join all doc comment lines
        return docCommentLines.joined(separator: "\n")
    }

    private static func generateParameterStruct(
        functionName: String,
        parameters: FunctionParameterListSyntax,
        docComment _: String?
    ) throws -> StructDeclSyntax {
        let structName = "\(functionName.capitalizedFirstLetter)Parameters"
        
        // Check if we have any parameters with meaningful default values (not nil)
        let hasDefaultValues = parameters.contains { param in
            guard let defaultValue = param.defaultValue else { return false }
            // Skip nil default values - they should be treated as optional parameters
            return defaultValue.value.description != "nil"
        }
        
        var propertyDeclarations: [String] = []
        var decodingStatements: [String] = []
        
        for param in parameters {
            let paramName = param.secondName?.text ?? param.firstName.text
            let paramType = param.type
            
            if let defaultValue = param.defaultValue, defaultValue.value.description != "nil" {
                // Parameter has meaningful default value - make it optional in decoding
                propertyDeclarations.append("let \(paramName): \(paramType)")
                decodingStatements.append("self.\(paramName) = try container.decodeIfPresent(\(paramType).self, forKey: .\(paramName)) ?? \(defaultValue.value)")
            } else {
                // Required parameter (including nil defaults, which should be treated as optional)
                propertyDeclarations.append("let \(paramName): \(paramType)")
                decodingStatements.append("self.\(paramName) = try container.decode(\(paramType).self, forKey: .\(paramName))")
            }
        }
        
        if hasDefaultValues {
            // Generate struct with custom init(from:) decoder
            return try StructDeclSyntax(
                """
                struct \(raw: structName): Decodable {
                    \(raw: propertyDeclarations.joined(separator: "\n    "))
                    
                    init(from decoder: Decoder) throws {
                        let container = try decoder.container(keyedBy: CodingKeys.self)
                        \(raw: decodingStatements.joined(separator: "\n        "))
                    }
                    
                    private enum CodingKeys: String, CodingKey {
                        \(raw: parameters.map { param in
                            let paramName = param.secondName?.text ?? param.firstName.text
                            return "case \(paramName)"
                        }.joined(separator: "\n        "))
                    }
                }
                """
            )
        } else {
            // Simple struct without custom decoder
            return try StructDeclSyntax(
                """
                struct \(raw: structName): Decodable {
                    \(raw: propertyDeclarations.joined(separator: "\n    "))
                }
                """
            )
        }
    }

    private static func generateWrapperVariable(
        functionDecl: FunctionDeclSyntax,
        functionName: String,
        parameters: FunctionParameterListSyntax,
        docComment: String?
    ) throws -> VariableDeclSyntax {
        let variableName = "\(functionName)Call"
        let parameterStructName = "\(functionName.capitalizedFirstLetter)Parameters"

        // Parse function description from doc comment
        let functionDescription = parseFunctionDescription(from: docComment) ?? "Generated function"

        // Generate JSON schema properties
        let schemaProperties = try generateSchemaProperties(parameters: parameters, docComment: docComment)
        let requiredFields = generateRequiredFields(parameters: parameters)
        let functionCallArguments = generateFunctionCallArguments(parameters: parameters)
        
        // Detect if function is async or throws
        let isAsync = functionDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrows = functionDecl.signature.effectSpecifiers?.throwsSpecifier != nil
        
        // Build function call with appropriate keywords
        let awaitKeyword = isAsync ? "await " : ""
        let tryKeyword = isThrows ? "try " : ""
        let functionCall = "\(tryKeyword)\(awaitKeyword)\(functionName)(\(functionCallArguments))"

        return try VariableDeclSyntax(
            """
            var \(raw: variableName): OpenAIFunctionWrapper {
                OpenAIFunctionWrapper(
                    difinition: ChatQuery.ChatCompletionToolParam.FunctionDefinition(
                        name: "\(raw: functionName)",
                        description: "\(raw: functionDescription)",
                        parameters: AnyJSONSchema(fields: [
                            .type(.object),
                            .properties([\(raw: schemaProperties)]),
                            .required([\(raw: requiredFields)])
                        ])
                    )
                ) { [self] decoder, data, encoder in
                    let parameters = try decoder.decode(\(raw: parameterStructName).self, from: data)
                    let result = \(raw: functionCall)
                    return try encoder.encode(result)
                }
            }
            """
        )
    }

    private static func parseFunctionDescription(from docComment: String?) -> String? {
        guard let docComment = docComment else { return nil }

        // Extract first line of doc comment as function description
        let lines = docComment.components(separatedBy: .newlines)
        guard let firstLine = lines.first else { return nil }
        
        // Clean up doc comment markers
        let cleaned = firstLine
            .replacingOccurrences(of: "///", with: "")
            .replacingOccurrences(of: "/**", with: "")
            .replacingOccurrences(of: "*/", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func generateSchemaProperties(
        parameters: FunctionParameterListSyntax,
        docComment: String?
    ) throws -> String {
        var properties: [String] = []

        for param in parameters {
            let paramName = param.secondName?.text ?? param.firstName.text
            let paramType = param.type

            // Parse parameter description from doc comment
            let paramDescription = parseParameterDescription(paramName: paramName, from: docComment)

            // Generate schema for this parameter type using runtime helper
            let schema = if let description = paramDescription {
                "AnyJSONSchema.forType(\(paramType).self, description: \"\(description)\")"
            } else {
                "AnyJSONSchema.forType(\(paramType).self)"
            }

            let property = """
            "\(paramName)": \(schema)
            """
            properties.append(property)
        }

        return properties.joined(separator: ",\n                            ")
    }

    private static func generateRequiredFields(parameters: FunctionParameterListSyntax) -> String {
        var requiredFields: [String] = []

        for param in parameters {
            let paramName = param.secondName?.text ?? param.firstName.text

            // Check if parameter is optional (has default value or is Optional type)
            let isOptional = param.defaultValue != nil || isOptionalType(param.type)

            if !isOptional {
                requiredFields.append("\"\(paramName)\"")
            }
        }

        return requiredFields.joined(separator: ", ")
    }

    private static func generateFunctionCallArguments(parameters: FunctionParameterListSyntax) -> String {
        var arguments: [String] = []

        for param in parameters {
            let paramName = param.secondName?.text ?? param.firstName.text
            let firstName = param.firstName.text

            if firstName == "_" {
                arguments.append("parameters.\(paramName)")
            } else {
                arguments.append("\(firstName): parameters.\(paramName)")
            }
        }

        return arguments.joined(separator: ", ")
    }

    private static func parseParameterDescription(paramName: String, from docComment: String?) -> String? {
        guard let docComment = docComment else { return nil }

        // Look for parameter description in doc comment
        let lines = docComment.components(separatedBy: .newlines)
        var inParametersSection = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check if we're entering the Parameters section
            if trimmedLine.contains("Parameters:") || trimmedLine.contains("Parameter:") {
                inParametersSection = true
                continue
            }

            // If we're in parameters section, look for our parameter
            if inParametersSection {
                // Handle various formats:
                // - paramName: description
                // ///  - paramName: description
                // - Parameter paramName: description
                if trimmedLine.contains("- \(paramName):") {
                    let description = trimmedLine.replacingOccurrences(of: "- \(paramName):", with: "")
                        .replacingOccurrences(of: "///", with: "")
                        .replacingOccurrences(of: "/**", with: "")
                        .replacingOccurrences(of: "*/", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return description.isEmpty ? nil : description
                }

                // Handle "- Parameter paramName: description" format
                if trimmedLine.contains("- Parameter \(paramName):") {
                    let description = trimmedLine.replacingOccurrences(of: "- Parameter \(paramName):", with: "")
                        .replacingOccurrences(of: "///", with: "")
                        .replacingOccurrences(of: "/**", with: "")
                        .replacingOccurrences(of: "*/", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return description.isEmpty ? nil : description
                }

                // Stop if we hit another section or empty line after parameters
                if trimmedLine.isEmpty || (trimmedLine.starts(with: "- ") && !trimmedLine.contains(paramName)) {
                    // Continue looking for our parameter
                    continue
                }
            }
        }

        return nil
    }

    private static func isOptionalType(_ type: TypeSyntax) -> Bool {
        // Check if type is Optional
        if type.is(OptionalTypeSyntax.self) {
            return true
        }

        // Check if type is Optional<T> syntax
        if let identifierType = type.as(IdentifierTypeSyntax.self) {
            return identifierType.name.text == "Optional"
        }

        return false
    }
}

enum MacroError: Error {
    case notAFunction
}

extension String {
    var capitalizedFirstLetter: String {
        return prefix(1).uppercased() + dropFirst()
    }
}

@main
struct OpenAIMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        OpenAIFunctionMacro.self,
    ]
}
