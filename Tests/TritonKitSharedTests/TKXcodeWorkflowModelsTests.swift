import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKXcodeWorkflowModelsTests {
    @Test("xcode workspace defaults round trip without losing simulator default")
    func xcodeDefaultsRoundTrip() throws {
        let defaults = TKHostWorkspaceDefaults(
            defaultSimulatorUDID: "SIM-1",
            xcode: TKXcodeWorkspaceDefaults(
                workspace: "App.xcworkspace",
                project: nil,
                scheme: "App",
                configuration: "Debug",
                sdk: "iphonesimulator",
                destination: "platform=iOS Simulator,id=SIM-1",
                derivedDataPath: ".triton/DerivedData/App"
            )
        )

        let decoded = try JSONDecoder().decode(TKHostWorkspaceDefaults.self, from: JSONEncoder().encode(defaults))

        #expect(decoded.defaultSimulatorUDID == "SIM-1")
        #expect(decoded.xcode?.workspace == "App.xcworkspace")
        #expect(decoded.xcode?.scheme == "App")
        #expect(decoded.xcode?.destination == "platform=iOS Simulator,id=SIM-1")
    }

    @Test("xcodebuild command builder emits stable argv")
    func xcodebuildCommandBuilder() {
        let build = TKXcodebuildCommand.build(
            workspace: "App.xcworkspace",
            project: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: ".triton/DerivedData/App"
        )

        #expect(TKXcodebuildCommand.listSchemes(workspace: "App.xcworkspace", project: nil).executable == "xcodebuild")
        #expect(TKXcodebuildCommand.listSchemes(workspace: "App.xcworkspace", project: nil).argv == ["-workspace", "App.xcworkspace", "-list", "-json"])
        let settings = TKXcodebuildCommand.showBuildSettings(workspace: "App.xcworkspace", project: nil, scheme: "App", configuration: "Debug", sdk: "iphonesimulator", destination: "platform=iOS Simulator,id=SIM-1", derivedDataPath: ".triton/DerivedData/App")
        #expect(settings.argv.contains("-showBuildSettings"))
        #expect(settings.defaultTimeoutSeconds == 300)
        #expect(settings.withTimeout(1_800).defaultTimeoutSeconds == 1_800)
        #expect(build.argv == [
            "-workspace", "App.xcworkspace",
            "-scheme", "App",
            "-configuration", "Debug",
            "-sdk", "iphonesimulator",
            "-destination", "platform=iOS Simulator,id=SIM-1",
            "-derivedDataPath", ".triton/DerivedData/App",
            "build",
        ])

        let signedDeviceBuild = TKXcodebuildCommand.build(
            workspace: nil,
            project: "App.xcodeproj",
            scheme: "App",
            configuration: "Debug",
            sdk: "iphoneos",
            destination: "generic/platform=iOS",
            derivedDataPath: ".triton/DerivedData/App",
            allowProvisioningUpdates: true
        )
        #expect(signedDeviceBuild.argv == [
            "-project", "App.xcodeproj",
            "-scheme", "App",
            "-configuration", "Debug",
            "-sdk", "iphoneos",
            "-destination", "generic/platform=iOS",
            "-derivedDataPath", ".triton/DerivedData/App",
            "-allowProvisioningUpdates",
            "build",
        ])
    }

    @Test("xctrace and coverage command builders emit stable argv")
    func xctraceAndCoverageCommandBuilders() {
        let trace = TKXctraceCommand.record(
            template: "Time Profiler",
            output: "/tmp/App.trace",
            device: "SIM-1",
            timeLimit: "5s",
            allProcesses: true,
            attach: nil,
            launchCommand: []
        )
        #expect(trace.executable == "xcrun")
        #expect(trace.argv == [
            "xctrace", "record",
            "--template", "Time Profiler",
            "--output", "/tmp/App.trace",
            "--device", "SIM-1",
            "--time-limit", "5s",
            "--all-processes",
            "--no-prompt",
        ])
        #expect(trace.capturesArtifacts)

        let coverage = TKXccovCommand.viewReport(
            xcresult: "/tmp/App.xcresult",
            mode: .filesForTarget("App"),
            json: true
        )
        #expect(coverage.executable == "xcrun")
        #expect(coverage.argv == [
            "xccov", "view",
            "--report",
            "--files-for-target", "App",
            "--json",
            "/tmp/App.xcresult",
        ])
    }

    @Test("xcresult command builders emit stable argv")
    func xcresultCommandBuilders() {
        let summary = TKXcresultCommand.summary(path: "/tmp/App.xcresult")
        let tests = TKXcresultCommand.tests(path: "/tmp/App.xcresult")

        #expect(summary.executable == "xcrun")
        #expect(summary.argv == [
            "xcresulttool", "get", "test-results", "summary",
            "--path", "/tmp/App.xcresult",
            "--compact",
        ])
        #expect(tests.argv == [
            "xcresulttool", "get", "test-results", "tests",
            "--path", "/tmp/App.xcresult",
            "--compact",
        ])
    }

    @Test("xcode action progress and summary preserve streaming artifacts")
    func xcodeStreamingArtifactsRoundTrip() throws {
        let cache = TKXcodeDerivedDataCacheState(
            derivedDataPath: ".triton/DerivedData",
            exists: true,
            cacheState: "warm",
            incrementalExpected: true
        )
        let event = TKXcodeProgressEvent(
            event: "xcode.build.heartbeat",
            message: "running",
            sourceCommand: "xcodebuild test",
            elapsedMs: 12_000,
            stdoutLogPath: "/tmp/triton-xcode-artifacts/case/stdout.log",
            stderrLogPath: "/tmp/triton-xcode-artifacts/case/stderr.log",
            stdoutBytes: 1_024,
            stderrBytes: 128,
            derivedDataPath: cache.derivedDataPath,
            cacheState: cache.cacheState,
            incrementalExpected: cache.incrementalExpected
        )
        let decodedEvent = try JSONDecoder().decode(TKXcodeProgressEvent.self, from: JSONEncoder().encode(event))

        #expect(decodedEvent.stdoutLogPath == "/tmp/triton-xcode-artifacts/case/stdout.log")
        #expect(decodedEvent.stderrLogPath == "/tmp/triton-xcode-artifacts/case/stderr.log")
        #expect(decodedEvent.stdoutBytes == 1_024)
        #expect(decodedEvent.stderrBytes == 128)
        #expect(decodedEvent.derivedDataPath == ".triton/DerivedData")
        #expect(decodedEvent.cacheState == "warm")
        #expect(decodedEvent.incrementalExpected == true)

        let summary = TKXcodeActionSummary(
            ok: true,
            action: "xcode.test",
            workspace: "App.xcworkspace",
            project: nil,
            scheme: "App",
            configuration: "Debug",
            sdk: "iphonesimulator",
            destination: "platform=iOS Simulator,id=SIM-1",
            derivedDataPath: "/tmp/DerivedData",
            resultBundlePath: "/tmp/App.xcresult",
            durationMs: 25_000,
            sourceCommand: "xcodebuild test",
            exitCode: 0,
            stdoutTruncated: false,
            stderrTruncated: false,
            stdoutLogPath: "/tmp/triton-xcode-artifacts/case/stdout.log",
            stderrLogPath: "/tmp/triton-xcode-artifacts/case/stderr.log",
            stdoutBytes: 2_048,
            stderrBytes: 512,
            testResultSummary: TKXcresultSummaryMetrics(
                title: "AppTests",
                startTime: 10.0,
                finishTime: 12.5,
                environmentDescription: "iPhone 17, iOS 26.5",
                topInsights: [],
                result: "Failed",
                durationMs: 2_500,
                totalTestCount: 2,
                passedTests: 1,
                failedTests: 1,
                skippedTests: 0,
                expectedFailures: 0,
                statistics: [],
                devicesAndConfigurations: nil,
                testFailure: nil
            ),
            topFailures: [
                TKXcresultFailureRecord(
                    suiteName: "LoginTests",
                    testName: "testSubmit()",
                    targetName: "AppTests",
                    message: "Expected Home",
                    location: "LoginTests.swift:42"
                ),
            ],
            xcresultNote: "Showing top 1 of 2 failures.",
            derivedDataCache: cache
        )
        let decodedSummary = try JSONDecoder().decode(TKXcodeActionSummary.self, from: JSONEncoder().encode(summary))

        #expect(decodedSummary.stdoutLogPath == "/tmp/triton-xcode-artifacts/case/stdout.log")
        #expect(decodedSummary.stderrLogPath == "/tmp/triton-xcode-artifacts/case/stderr.log")
        #expect(decodedSummary.stdoutBytes == 2_048)
        #expect(decodedSummary.stderrBytes == 512)
        #expect(decodedSummary.testResultSummary?.failedTests == 1)
        #expect(decodedSummary.topFailures?.map { $0.testName } == ["testSubmit()"])
        #expect(decodedSummary.xcresultNote == "Showing top 1 of 2 failures.")
        #expect(decodedSummary.derivedDataCache?.cacheState == "warm")
        #expect(decodedSummary.derivedDataCache?.incrementalExpected == true)
    }

    @Test("xcodebuild list json parser returns schemes")
    func xcodebuildListParser() throws {
        let json = """
        {
          "workspace": {
            "name": "App",
            "schemes": ["App", "AppTests"]
          }
        }
        """

        let output = try TKXcodebuildListParser.parseSchemes(Data(json.utf8))

        #expect(output.containerName == "App")
        #expect(output.schemes == ["App", "AppTests"])
    }

    @Test("xcodebuild build settings parser resolves app product and bundle id")
    func xcodebuildBuildSettingsParser() throws {
        let json = """
        [
          {
            "target": "App",
            "buildSettings": {
              "BUILT_PRODUCTS_DIR": "/tmp/DerivedData/Build/Products/Debug-iphonesimulator",
              "FULL_PRODUCT_NAME": "App.app",
              "PRODUCT_BUNDLE_IDENTIFIER": "com.example.App"
            }
          }
        ]
        """

        let product = try TKXcodeBuildSettingsParser.resolveBuiltApp(Data(json.utf8))

        #expect(product.target == "App")
        #expect(product.appPath == "/tmp/DerivedData/Build/Products/Debug-iphonesimulator/App.app")
        #expect(product.bundleID == "com.example.App")
    }

    @Test("xcresult summary parser resolves counts and duration")
    func xcresultSummaryParser() throws {
        let json = """
        {
          "title": "AppTests",
          "startTime": 10.0,
          "finishTime": 12.5,
          "environmentDescription": "iPhone 17, iOS 26.5",
          "topInsights": [
            { "impact": "high", "category": "assertion", "text": "One failing test" }
          ],
          "result": "Failed",
          "totalTestCount": 3,
          "passedTests": 2,
          "failedTests": 1,
          "skippedTests": 0,
          "expectedFailures": 0,
          "statistics": [
            { "title": "Tests", "subtitle": "3 total" }
          ],
          "devicesAndConfigurations": {
            "device": {
              "deviceId": "SIM-1",
              "deviceName": "iPhone 17",
              "architecture": "arm64",
              "modelName": "iPhone 17",
              "platform": "iOS",
              "osVersion": "26.5",
              "osBuildNumber": "23F"
            },
            "testPlanConfiguration": {
              "configurationId": "cfg-1",
              "configurationName": "Debug"
            },
            "passedTests": 2,
            "failedTests": 1,
            "skippedTests": 0,
            "expectedFailures": 0
          },
          "testFailures": {
            "testName": "AppTests/testLogin()",
            "targetName": "AppTests",
            "failureText": "XCTAssertEqual failed: 1 is not equal to 2",
            "testIdentifier": 42,
            "testIdentifierString": "42",
            "testIdentifierURL": "xcresult://test/42"
          }
        }
        """

        let summary = try TKXcresultSummaryParser.parse(Data(json.utf8))

        #expect(summary.title == "AppTests")
        #expect(summary.status == "failed")
        #expect(summary.durationMs == 2_500)
        #expect(summary.totalTestCount == 3)
        #expect(summary.failedTests == 1)
        #expect(summary.devicesAndConfigurations?.device.deviceName == "iPhone 17")
        #expect(summary.testFailure?.testIdentifierString == "42")
    }

    @Test("xcresult redaction removes private paths emails and token-like values")
    func xcresultRedactionRemovesSensitiveStrings() {
        let summary = TKXcresultSummaryMetrics(
            title: "AppTests",
            startTime: nil,
            finishTime: nil,
            environmentDescription: "runner=/Users/alice/Private/App token=abc123456789secret alice@example.com",
            topInsights: [
                TKXcresultInsightSummary(
                    impact: "high",
                    category: "assertion",
                    text: "Bearer sk_test_1234567890abcdef1234567890abcdef at /Users/alice/App/Tests/LoginTests.swift:42"
                )
            ],
            result: "Failed",
            totalTestCount: 1,
            passedTests: 0,
            failedTests: 1,
            skippedTests: 0,
            expectedFailures: 0,
            statistics: [],
            devicesAndConfigurations: nil,
            testFailure: TKXcresultTestFailure(
                testName: "testLogin()",
                targetName: "AppTests",
                failureText: "failed for alice@example.com password=hunter2secret",
                testIdentifierString: "42",
                testIdentifierURL: "xcresult://test/42"
            )
        )
        let failures = [
            TKXcresultFailureRecord(
                suiteName: "LoginSuite",
                testName: "testLogin()",
                targetName: "AppTests",
                message: "XCTAssert failed at /Users/alice/App/Tests/LoginTests.swift with token=1234567890abcdef1234567890abcdef",
                location: "/Users/alice/App/Tests/LoginTests.swift:42",
                attachmentNames: ["file:///Users/alice/App/shot.png"]
            )
        ]

        let redactedSummary = TKXcresultRedaction.redact(summary)
        let redactedFailures = TKXcresultRedaction.redact(failures)
        let encodedSummary = String(data: try! JSONEncoder().encode(redactedSummary), encoding: .utf8)!
        let encodedFailures = String(data: try! JSONEncoder().encode(redactedFailures), encoding: .utf8)!

        #expect(!encodedSummary.contains("/Users/alice"))
        #expect(!encodedSummary.contains("alice@example.com"))
        #expect(!encodedSummary.contains("sk_test_1234567890abcdef1234567890abcdef"))
        #expect(encodedSummary.contains("<private-path>"))
        #expect(encodedSummary.contains("<email>"))
        #expect(encodedSummary.contains("Bearer <redacted>"))
        #expect(!encodedFailures.contains("/Users/alice"))
        #expect(!encodedFailures.contains("1234567890abcdef1234567890abcdef"))
        #expect(encodedFailures.contains("<private-path>"))
        #expect(encodedFailures.contains("token=<redacted>"))
    }

    @Test("xcresult tests parser extracts structured failures")
    func xcresultTestsParser() throws {
        let json = """
        {
          "testPlanConfigurations": [
            { "configurationId": "cfg-1", "configurationName": "Debug" }
          ],
          "devices": [
            {
              "deviceId": "SIM-1",
              "deviceName": "iPhone 17",
              "architecture": "arm64",
              "modelName": "iPhone 17",
              "platform": "iOS",
              "osVersion": "26.5",
              "osBuildNumber": "23F"
            }
          ],
          "testNodes": [
            {
              "nodeIdentifier": "bundle-1",
              "nodeIdentifierURL": "xcresult://bundle/1",
              "nodeType": "Unit test bundle",
              "name": "AppTests",
              "children": [
                {
                  "nodeIdentifier": "suite-1",
                  "nodeIdentifierURL": "xcresult://suite/1",
                  "nodeType": "Test Suite",
                  "name": "AppTests",
                  "children": [
                    {
                      "nodeIdentifier": "case-1",
                      "nodeIdentifierURL": "xcresult://case/1",
                      "nodeType": "Test Case",
                      "name": "testLogin()",
                      "children": [
                        {
                          "nodeIdentifier": "run-1",
                          "nodeIdentifierURL": "xcresult://run/1",
                          "nodeType": "Test Case Run",
                          "name": "testLogin()",
                          "result": "Failed",
                          "children": [
                            {
                              "nodeIdentifier": "failure-1",
                              "nodeType": "Failure Message",
                              "name": "XCTAssertEqual failed",
                              "details": "XCTAssertEqual failed: 1 is not equal to 2"
                            },
                            {
                              "nodeIdentifier": "source-1",
                              "nodeType": "Source Code Reference",
                              "name": "Tests/AppTests.swift:42",
                              "details": "Tests/AppTests.swift:42"
                            },
                            {
                              "nodeIdentifier": "attachment-1",
                              "nodeType": "Attachment",
                              "name": "Screenshot",
                              "details": "Screenshot"
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """

        let failures = try TKXcresultTestsParser.parseFailures(Data(json.utf8))

        #expect(failures.count == 1)
        #expect(failures.first?.suiteName == "AppTests")
        #expect(failures.first?.testName == "testLogin()")
        #expect(failures.first?.targetName == "AppTests")
        #expect(failures.first?.location == "Tests/AppTests.swift:42")
        #expect(failures.first?.attachmentNames == ["Screenshot"])
        #expect(failures.first?.message.contains("XCTAssertEqual failed") == true)
    }

    @Test("xcresult tests parser tolerates nodes without identifiers")
    func xcresultTestsParserToleratesMissingIdentifiers() throws {
        let json = """
        {
          "testPlanConfigurations": [],
          "devices": [],
          "testNodes": [
            {
              "nodeType": "Unit test bundle",
              "name": "AppTests",
              "children": [
                {
                  "nodeType": "Test Suite",
                  "name": "AppTests",
                  "children": [
                    {
                      "nodeType": "Test Case",
                      "name": "testMissingIdentifier()",
                      "children": [
                        {
                          "nodeType": "Test Case Run",
                          "name": "testMissingIdentifier()",
                          "result": "Failed",
                          "children": [
                            {
                              "nodeType": "Failure Message",
                              "name": "XCTAssertTrue failed",
                              "details": "XCTAssertTrue failed"
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """

        let failures = try TKXcresultTestsParser.parseFailures(Data(json.utf8))

        #expect(failures.count == 1)
        #expect(failures.first?.testName == "testMissingIdentifier()")
        #expect(failures.first?.testIdentifierString == nil)
        #expect(failures.first?.message == "XCTAssertTrue failed")
    }

    @Test("xcresult tests parser keeps failed runs without diagnostic children")
    func xcresultTestsParserKeepsFailedRunsWithoutDiagnostics() throws {
        let json = """
        {
          "testPlanConfigurations": [],
          "devices": [],
          "testNodes": [
            {
              "nodeType": "Unit test bundle",
              "name": "AppTests",
              "children": [
                {
                  "nodeType": "Test Case",
                  "name": "testCrash()",
                  "children": [
                    {
                      "nodeType": "Test Case Run",
                      "name": "testCrash()",
                      "details": "Test crashed before recording a failure message",
                      "result": "Failed"
                    }
                  ]
                }
              ]
            }
          ]
        }
        """

        let failures = try TKXcresultTestsParser.parseFailures(Data(json.utf8))

        #expect(failures.count == 1)
        #expect(failures.first?.testName == "testCrash()")
        #expect(failures.first?.message == "Test crashed before recording a failure message")
    }

    @Test("xcode discovery finds workspace project and package without nested build noise")
    func xcodeDiscovery() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("triton-xcode-discovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Demo.xcworkspace"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Demo.xcodeproj"), withIntermediateDirectories: true)
        try "swift-tools-version: 6.0".write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try TKXcodeProjectDiscovery.discover(path: root.path, maxDepth: 2)

        #expect(result.ok)
        #expect(result.workspaces.map(\.name) == ["Demo.xcworkspace"])
        #expect(result.projects.map(\.name) == ["Demo.xcodeproj"])
        #expect(result.packages.map(\.name) == ["Package.swift"])
        #expect(result.recommendedContainer?.path.hasSuffix("Demo.xcworkspace") == true)
    }
}
