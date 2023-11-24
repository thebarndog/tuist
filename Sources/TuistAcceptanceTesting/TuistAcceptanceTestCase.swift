// swiftlint:disable force_try
import TSCBasic
import TuistCore
import TuistGraph
@_exported import TuistKit
import XCTest

@testable import TuistSupport
@testable import TuistSupportTesting

public enum Destination {
    case simulator, device
}

open class TuistAcceptanceTestCase: XCTestCase {
    public var xcodeprojPath: AbsolutePath!
    public var workspacePath: AbsolutePath!
    public var fixturePath: AbsolutePath!
    public var derivedDataPath: AbsolutePath!
    public var environment: MockEnvironment!

    private var sourceRootPath: AbsolutePath!
    private var fixtureTemporaryDirectory: TemporaryDirectory!

    override open func setUp() {
        super.setUp()

        derivedDataPath = try! TemporaryDirectory(removeTreeOnDeinit: true).path
        fixtureTemporaryDirectory = try! TemporaryDirectory(removeTreeOnDeinit: true)

        sourceRootPath = try! AbsolutePath(
            validating: ProcessInfo.processInfo.environment[
                "TUIST_CONFIG_SRCROOT"
            ]!
        )

        do {
            // Environment
            environment = try MockEnvironment()
            Environment.shared = environment
        } catch {
            XCTFail("Failed to setup environment")
        }
    }

    override open func tearDown() async throws {
        xcodeprojPath = nil
        workspacePath = nil
        fixturePath = nil
        fixtureTemporaryDirectory = nil
        derivedDataPath = nil

        try await super.tearDown()
    }

    public func setUpFixture(_ fixture: String) throws {
        let fixturesPath = sourceRootPath
            .appending(component: "fixtures")

        fixturePath = fixtureTemporaryDirectory.path.appending(component: fixture)

        try FileHandler.shared.copy(
            from: fixturesPath.appending(component: fixture),
            to: fixturePath
        )
    }

    public func run(_ command: (some AsyncParsableCommand).Type, _ arguments: [String] = []) async throws {
        let arguments = arguments + [
            "--path", fixturePath.pathString,
        ]

        var parsedCommand = try command.parse(arguments)
        try await parsedCommand.run()
    }

    public func run(_ command: TestCommand.Type, _ arguments: [String] = []) async throws {
        let arguments = arguments + [
            "--derived-data-path", derivedDataPath.pathString,
            "--path", fixturePath.pathString,
        ]

        let parsedCommand = try command.parse(arguments)
        try await parsedCommand.run()
    }

    public func run(_ command: BuildCommand.Type, _ arguments: [String] = []) async throws {
        let arguments = arguments + [
            "--derived-data-path", derivedDataPath.pathString,
            "--path", fixturePath.pathString,
        ]

        let parsedCommand = try command.parse(arguments)
        try await parsedCommand.run()
    }

    public func run(_ command: GenerateCommand.Type, _ arguments: [String] = []) async throws {
        let arguments = arguments + [
            "--no-open",
            "--path", fixturePath.pathString,
        ]

        let parsedCommand = try command.parse(arguments)
        try await parsedCommand.run()

        xcodeprojPath = try FileHandler.shared.contentsOfDirectory(fixturePath)
            .first(where: { $0.extension == "xcodeproj" })
        workspacePath = try FileHandler.shared.contentsOfDirectory(fixturePath)
            .first(where: { $0.extension == "xcworkspace" })
    }

    public func run(_ command: (some AsyncParsableCommand).Type, _ arguments: String...) async throws {
        try await run(command, Array(arguments))
    }

    public func run(_ command: (some ParsableCommand).Type, _ arguments: [String] = []) throws {
        if String(describing: command) == "InitCommand" {
            fixturePath = fixtureTemporaryDirectory.path.appending(
                component: arguments[arguments.firstIndex(where: { $0 == "--name" })! + 1]
            )
        }
        var parsedCommand = try command.parseAsRoot(
            arguments +
                ["--path", fixturePath.pathString]
        )
        try parsedCommand.run()
    }

    public func run(_ command: (some ParsableCommand).Type, _ arguments: String...) throws {
        try run(command, Array(arguments))
    }

    public func addEmptyLine(to file: String) throws {
        let filePath = try fixturePath.appending(RelativePath(validating: file))
        var contents = try FileHandler.shared.readTextFile(filePath)
        contents += "\n"
        try FileHandler.shared.write(contents, path: filePath, atomically: true)
    }
}

// swiftlint:enable force_try