// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "OpenAIMacros",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OpenAIMacros",
            targets: ["OpenAIMacros"]
        ),
        .executable(
            name: "OpenAIMacrosClient",
            targets: ["OpenAIMacrosClient"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/MacPaw/OpenAI", from: "0.2.4"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .macro(
            name: "OpenAIMacrosMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "OpenAIMacros",
            dependencies: [
                "OpenAIMacrosMacros",
                .product(name: "OpenAI", package: "OpenAI"),
            ]
        ),

        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(
            name: "OpenAIMacrosClient",
            dependencies: ["OpenAIMacros"]
        ),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "OpenAIMacrosTests",
            dependencies: [
				"OpenAIMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
