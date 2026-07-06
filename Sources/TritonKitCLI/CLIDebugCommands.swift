import ArgumentParser

struct Debug: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "debug",
        abstract: "Explicit raw engine and runtime inspection surface",
        discussion: """
        Debug groups low-level runtime and engine inspection commands under an
        explicit raw surface. Prefer workflow commands such as observe, act,
        verify, and evidence for normal automation flows.
        """,
        subcommands: [
            Runtime.self,
            State.self,
            Snapshot.self,
            Hierarchy.self,
            Nodes.self,
            Node.self,
            PatchNode.self,
            Attrs.self,
            ObjectInfo.self,
            Geometry.self,
            AccessibilityTree.self,
            Hit.self,
            Ledger.self,
        ]
    )
}
