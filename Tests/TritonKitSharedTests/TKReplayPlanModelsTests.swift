import Foundation
import Testing
@testable import TritonKitShared

@Suite
struct TKReplayPlanModelsTests {
    @Test("plan decodes issue login flow shape")
    func decodesLoginFlowShape() throws {
        let json = """
        {
          "schemaVersion": 1,
          "name": "dxyer-login",
          "variables": ["username", "password"],
          "steps": [
            { "action": "tap", "text": "登录" },
            { "action": "tap", "x": 180, "y": 250 },
            { "action": "paste", "value": "${username}" },
            { "action": "wait", "gone": "登录", "timeout": 15 },
            { "action": "evidence", "name": "login-success" }
          ]
        }
        """

        let plan = try JSONDecoder().decode(TKReplayPlan.self, from: Data(json.utf8))

        #expect(plan.schemaVersion == 1)
        #expect(plan.name == "dxyer-login")
        #expect(plan.variables == ["username", "password"])
        #expect(plan.steps.count == 5)
        #expect(plan.steps[0].action == .tap)
        #expect(plan.steps[0].text == "登录")
        #expect(plan.steps[1].x == 180)
        #expect(plan.steps[2].value == "${username}")
        #expect(plan.steps[3].waitCondition == .gone)
        #expect(plan.steps[3].timeout == 15)
        #expect(plan.steps[4].name == "login-success")
    }

    @Test("variable substitution reports missing values")
    func substitutesVariables() throws {
        #expect(try TKReplaySubstituteVariables("hello ${username}", variables: ["username": "alice"]) == "hello alice")
        #expect(throws: TKReplayVariableError.self) {
            _ = try TKReplaySubstituteVariables("${password}", variables: [:])
        }
    }

    @Test("secure replay step redacts value for summaries")
    func secureRedactedSummary() throws {
        let step = TKReplayPlanStep(action: .paste, value: "secret-123", secure: true)
        let nonSecureStep = TKReplayPlanStep(action: .paste, value: "alice", secure: false)

        #expect(step.redactedValue(substitutedValue: "secret-123") == "<redacted:10>")
        #expect(nonSecureStep.redactedValue(substitutedValue: "alice") == "alice")
    }

    @Test("record response states template only")
    func recordTemplateResponseShape() throws {
        let plan = TKReplayPlan.template(name: "login-flow")
        let response = TKRecordPlanResponse(
            ok: true,
            output: "/tmp/login-flow.tritonplan",
            templateOnly: true,
            message: "Created editable Triton replay plan template",
            plan: plan
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(TKRecordPlanResponse.self, from: data)

        #expect(decoded.templateOnly)
        #expect(decoded.plan.steps.contains { $0.action == .evidence })
    }
}
