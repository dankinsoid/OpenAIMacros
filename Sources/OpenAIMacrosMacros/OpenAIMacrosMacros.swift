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
        // Extract doc comment from leading trivia
        for trivia in funcDecl.leadingTrivia {
            if case let .docLineComment(comment) = trivia {
                return comment
            }
            if case let .docBlockComment(comment) = trivia {
                return comment
            }
        }
        return nil
    }

    private static func generateParameterStruct(
        functionName: String,
        parameters: FunctionParameterListSyntax,
        docComment _: String?
    ) throws -> StructDeclSyntax {
        let structName = "\(functionName.capitalizedFirstLetter)Parameters"

        var structMembers: [MemberBlockItemSyntax] = []

        for param in parameters {
            let paramName = param.secondName?.text ?? param.firstName.text
            let paramType = param.type

            // Create struct property
            let property = VariableDeclSyntax(
                bindingSpecifier: .keyword(.let),
                bindings: PatternBindingListSyntax([
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: .identifier(paramName)),
                        typeAnnotation: TypeAnnotationSyntax(type: paramType)
                    ),
                ])
            )

            structMembers.append(MemberBlockItemSyntax(decl: property))
        }

        return StructDeclSyntax(
            name: .identifier(structName),
            inheritanceClause: InheritanceClauseSyntax(
                inheritedTypes: InheritedTypeListSyntax([
                    InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("Codable"))),
                    InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("Hashable"))),
                    InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("Sendable"))),
                ])
            ),
            memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax(structMembers))
        )
    }

    private static func generateWrapperVariable(
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
                    let result = \(raw: functionName)(\(raw: functionCallArguments))
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
        return lines.first?.trimmingCharacters(in: .whitespacesAndNewlines)
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
            var schema = "try AnyJSONSchema.forType(\(paramType).self)"

            // Add description if available
            if let description = paramDescription {
                schema = """
                {
                    var schema = try AnyJSONSchema.forType(\(paramType).self)
                    schema.fields.append(.description("\(description)"))
                    return schema
                }()
                """
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
                    return trimmedLine.replacingOccurrences(of: "- \(paramName):", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // Handle "- Parameter paramName: description" format
                if trimmedLine.contains("- Parameter \(paramName):") {
                    return trimmedLine.replacingOccurrences(of: "- Parameter \(paramName):", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
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
