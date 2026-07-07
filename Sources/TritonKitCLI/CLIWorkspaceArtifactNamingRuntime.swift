import Foundation

func workspaceArtifactSuffix(_ index: Int) -> String {
    String(format: "%03d", max(0, index))
}

func workspaceGraphSuffix(_ index: Int) -> String {
    String(format: "%04d", max(0, index))
}

func workspaceScreenID(_ index: Int) -> String {
    "screen_\(workspaceGraphSuffix(index))"
}

func workspaceStateID(_ index: Int) -> String {
    "state_\(workspaceGraphSuffix(index))"
}
