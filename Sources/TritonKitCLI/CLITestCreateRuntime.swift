import Foundation

func createTritonTestFromSession(
    input: String,
    output: String,
    name: String? = nil
) throws -> TKTestCreateResponse {
    let root = evidenceBundleRoot(from: input)
    _ = try readEvidenceManifest(from: input)

    let normalizedPlanURL = root.appendingPathComponent("normalized-plan.json")
    guard FileManager.default.fileExists(atPath: normalizedPlanURL.path) else {
        throw RuntimeError("Missing normalized-plan.json at \(normalizedPlanURL.path)")
    }

    var plan = try JSONDecoder().decode(TKTestNormalizedPlan.self, from: Data(contentsOf: normalizedPlanURL))
    if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        plan = TKTestNormalizedPlan(
            name: name,
            app: plan.app,
            device: plan.device,
            settings: plan.settings,
            steps: plan.steps
        )
    }

    let yaml = renderTritonTestYAML(from: plan)
    let outputURL = URL(fileURLWithPath: output)
    let outputDirectory = outputURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    try yaml.write(to: outputURL, atomically: true, encoding: .utf8)

    let validated = try validateTritonTestContract(yaml: yaml, inputPath: outputURL.path)
    let validation = TKTestValidationResponse(input: outputURL.path, normalizedPlan: validated)

    return TKTestCreateResponse(
        input: root.path,
        output: outputURL.path,
        source: "normalized-plan.json",
        name: validated.name,
        stepCount: validated.steps.count,
        validation: validation,
        suggestedCommands: [
            "triton test validate \(shellQuotedEvidencePath(outputURL.path)) --json",
            "triton test run \(shellQuotedEvidencePath(outputURL.path)) --json --evidence-dir \(shellQuotedEvidencePath(outputURL.deletingPathExtension().path + ".tritonevidence"))",
        ]
    )
}

private func renderTritonTestYAML(from plan: TKTestNormalizedPlan) -> String {
    var lines: [String] = []
    lines.append("version: 1")
    lines.append("name: \(yamlScalar(plan.name))")
    lines.append("app:")
    lines.append("  bundleId: \(yamlScalar(plan.app.bundleId))")
    lines.append("device:")
    lines.append("  platform: \(yamlScalar(plan.device.platform))")
    lines.append("settings:")
    lines.append("  strict: \(plan.settings.strict ? "true" : "false")")
    lines.append("  timeoutMs: \(plan.settings.timeoutMs)")
    lines.append("  retry:")
    lines.append("    count: \(plan.settings.retry.count)")
    lines.append("    intervalMs: \(plan.settings.retry.intervalMs)")
    lines.append("steps:")
    for step in plan.steps {
        appendYAML(for: step, to: &lines)
    }
    lines.append("")
    return lines.joined(separator: "\n")
}

private func appendYAML(for step: TKTestPlanStep, to lines: inout [String]) {
    lines.append("  - id: \(yamlScalar(step.id))")
    if step.optional {
        lines.append("    optional: true")
    }
    if let timeoutMs = step.timeoutMs {
        lines.append("    timeoutMs: \(timeoutMs)")
    }

    switch step.type {
    case "launch", "stop", "takeScreenshot":
        lines.append("    \(step.type): {}")
    case "tap":
        lines.append("    tap:")
        if let point = step.point {
            appendPoint(point, key: "point", indent: "      ", to: &lines)
        } else if let selector = step.selector {
            appendSelector(selector, indent: "      ", to: &lines)
        } else if let target = step.target {
            lines.append("      target: \(yamlScalar(target))")
            if let grounding = step.grounding {
                lines.append("      grounding: \(yamlScalar(grounding))")
            }
            if let provider = step.provider {
                lines.append("      provider: \(yamlScalar(provider))")
            }
            if let model = step.model {
                lines.append("      model: \(yamlScalar(model))")
            }
            if let modelPath = step.modelPath {
                lines.append("      modelPath: \(yamlScalar(modelPath))")
            }
            if let maxTokens = step.maxTokens {
                lines.append("      maxTokens: \(maxTokens)")
            }
            if let temperature = step.temperature {
                lines.append("      temperature: \(formatYAMLNumber(temperature))")
            }
            if let seed = step.seed {
                lines.append("      seed: \(seed)")
            }
            if let promptTemplate = step.promptTemplate {
                lines.append("      promptTemplate: \(yamlScalar(promptTemplate))")
            }
            if let allowModelDownload = step.allowModelDownload {
                lines.append("      allowModelDownload: \(allowModelDownload ? "true" : "false")")
            }
        } else {
            lines.append("      point:")
            lines.append("        x: 0")
            lines.append("        y: 0")
            lines.append("        coordinateSpace: runtime-point")
        }
    case "input":
        lines.append("    input:")
        lines.append("      text: \(yamlScalar(step.text ?? ""))")
    case "press":
        lines.append("    press:")
        lines.append("      button: \(yamlScalar(step.button ?? ""))")
    case "swipe":
        lines.append("    swipe:")
        if let point = step.point {
            appendPoint(point, key: "from", indent: "      ", to: &lines)
        }
        if let endPoint = step.endPoint {
            appendPoint(endPoint, key: "to", indent: "      ", to: &lines)
        }
    case "assertVisible", "assertNotVisible":
        lines.append("    \(step.type):")
        if let selector = step.selector {
            appendSelector(selector, indent: "      ", to: &lines)
        }
    case "scrollUntilVisible":
        lines.append("    scrollUntilVisible:")
        if let selector = step.selector {
            appendSelector(selector, indent: "      ", to: &lines)
        }
        if let direction = step.direction {
            lines.append("      direction: \(yamlScalar(direction))")
        }
        if let maxScrolls = step.maxScrolls {
            lines.append("      maxScrolls: \(maxScrolls)")
        }
    case "assertWithAI", "assertNoDefectsWithAI", "extractTextWithAI":
        lines.append("    \(step.type):")
        if let provider = step.provider {
            lines.append("      provider: \(yamlScalar(provider))")
        }
        if let prompt = step.prompt {
            lines.append("      prompt: \(yamlScalar(prompt))")
        }
    case "assertScreenshot":
        lines.append("    assertScreenshot:")
        if let baseline = step.baseline {
            lines.append("      baseline: \(yamlScalar(baseline))")
        }
        if let threshold = step.threshold {
            lines.append("      threshold: \(formatYAMLNumber(threshold))")
        }
        if let cropOn = step.cropOn {
            lines.append("      cropOn: \(yamlScalar(cropOn))")
        }
    default:
        lines.append("    \(step.type): {}")
    }
}

private func appendSelector(_ selector: TKTestPlanSelector, indent: String, to lines: inout [String]) {
    lines.append("\(indent)text: \(yamlScalar(selector.text))")
    lines.append("\(indent)source: \(yamlScalar(selector.source))")
    lines.append("\(indent)match: \(yamlScalar(selector.match))")
}

private func appendPoint(_ point: TKTestPlanPoint, key: String, indent: String, to lines: inout [String]) {
    lines.append("\(indent)\(key):")
    lines.append("\(indent)  x: \(formatYAMLNumber(point.x))")
    lines.append("\(indent)  y: \(formatYAMLNumber(point.y))")
    lines.append("\(indent)  coordinateSpace: \(yamlScalar(point.coordinateSpace))")
}

private func yamlScalar(_ value: String) -> String {
    if let data = try? JSONEncoder().encode(value),
       let encoded = String(data: data, encoding: .utf8) {
        return encoded
    }
    return "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
}

private func formatYAMLNumber(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }
    return String(value)
}
