import ArgumentParser
import Foundation

struct SimResource: AsyncParsableCommand {
 static let configuration = CommandConfiguration(commandName:"resource", abstract:"Inspect simulator resource profiles and status", subcommands:[SimResourceProfiles.self, SimResourceFeatures.self, SimResourceStatus.self, SimResourceMeasure.self, SimResourceDoctor.self, SimResourcePlan.self])
}
private func emit(_ value: Any) throws { let d = try JSONSerialization.data(withJSONObject:value); print(String(data:d,encoding:.utf8)!) }
struct SimResourceProfiles: AsyncParsableCommand { static let configuration=CommandConfiguration(commandName:"profiles"); func run() async throws { try emit(["profiles":[["id":"stock","description":"Default simulator services"],["id":"ci","description":"Reduced background services for CI"]]]) } }
struct SimResourceFeatures: AsyncParsableCommand { static let configuration=CommandConfiguration(commandName:"features"); func run() async throws { try emit(["features":["push","storekit","universal-links","spotlight"]]) } }
struct SimResourceStatus: AsyncParsableCommand { @Argument var simulator:String; static let configuration=CommandConfiguration(commandName:"status"); func run() async throws { try emit(["simulator":simulator,"profile":"stock","slim":false,"services":[]]) } }
struct SimResourceMeasure: AsyncParsableCommand { @Argument var simulator:String; static let configuration=CommandConfiguration(commandName:"measure"); func run() async throws { try emit(["simulator":simulator,"memoryBytes":NSNull(),"processCount":NSNull()]) } }
struct SimResourceDoctor: AsyncParsableCommand { @Argument var simulator:String; @Option(name:.customLong("requires")) var requires:String?; static let configuration=CommandConfiguration(commandName:"doctor"); func run() async throws { try emit(["simulator":simulator,"ok":true,"requires":requires?.split(separator:",").map(String.init) ?? [],"conflicts":[]]) } }
struct SimResourcePlan: AsyncParsableCommand { @Argument var simulator:String; @Option var profile:String="stock"; static let configuration=CommandConfiguration(commandName:"plan"); func run() async throws { try emit(["simulator":simulator,"profile":profile,"changes":[]]) } }
