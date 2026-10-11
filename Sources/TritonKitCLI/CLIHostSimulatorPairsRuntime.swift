import Foundation
import TritonKitShared

func makeSimulatorPairsOutput(provider: (() throws -> Data)? = nil) throws -> HostSimulatorPairsOutput {
    do {
        let data = try (provider ?? {
            let result = try runHostCommand(TKSimulatorPairsParser.command())
            guard result.exitCode == 0, !result.stdoutTruncated else { throw TKSimulatorPairsError.invalidJSON }
            return result.stdoutData
        })()
        let pairs = try TKSimulatorPairsParser.parse(data)
        return HostSimulatorPairsOutput(pairs: pairs, sourceCommands: [hostSourceCommand(TKSimulatorPairsParser.command())])
    } catch { throw HostSimulatorPairsFailure(error) }
}
