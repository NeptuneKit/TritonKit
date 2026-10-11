import ArgumentParser

struct SimPairs: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "pairs", abstract: "Read native watch/phone Simulator relationships without changing pairing")
    @Flag(help: "Alias for --format json") var json = false
    @Option(help: "text|json") var format: ClientOutputFormat = .json
    func run() async throws {
        let outputFormat = effectiveFormat(format, json: json)
        do {
            let output = try makeSimulatorPairsOutput()
            switch outputFormat {
            case .json: print(try encodeJSON(output))
            case .text: for pair in output.pairs { print("\(pair.id)\t\(pair.watchID)\t\(pair.phoneID)\t\(pair.state)") }
            }
        } catch { try failHostCommand(error, outputFormat: outputFormat) }
    }
}
