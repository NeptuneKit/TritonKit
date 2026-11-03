#!/usr/bin/env python3
"""Generate an isolated app-hosted UIKit test project specification for SP-270."""
import json
from pathlib import Path
repo = Path(__file__).resolve().parents[4]
out = repo / '.build/sp270-validation-host'
out.mkdir(parents=True, exist_ok=True)
fixture = out / 'Fixture'
fixture.mkdir(exist_ok=True)
(fixture/'App.swift').write_text('''import UIKit
@main class AppDelegate: UIResponder, UIApplicationDelegate {
 func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
  let config = UISceneConfiguration(name: "Default", sessionRole: session.role)
  config.delegateClass = SceneDelegate.self
  return config
 }
}
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
 var window: UIWindow?
 func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
  guard let scene = scene as? UIWindowScene else { return }
  let window = UIWindow(windowScene: scene)
  let controller = UIViewController()
  controller.view.backgroundColor = .white
  let label = UILabel(frame: CGRect(x: 24, y: 80, width: 300, height: 40))
  label.text = "TritonKit Lookin Core Fixture"
  label.accessibilityIdentifier = "sp270-title"
  controller.view.addSubview(label)
  let parent = CALayer()
  parent.name = "sp270-red-parent"
  parent.frame = CGRect(x: 24, y: 150, width: 240, height: 240)
  parent.backgroundColor = UIColor.red.cgColor
  let child = CALayer()
  child.name = "sp270-blue-child"
  child.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
  child.backgroundColor = UIColor.blue.cgColor
  parent.addSublayer(child)
  controller.view.layer.addSublayer(parent)
  window.rootViewController = controller
  window.makeKeyAndVisible()
  self.window = window
  #if DEBUG
  startInspection()
  #endif
 }
}
''')
(fixture/'DebugBootstrap.swift').write_text('''#if DEBUG
import TritonKit
func startInspection() { TritonKit.shared.start() }
#endif
''')
tests = ['TKHierarchyDetailsTests.swift', 'TKUIKitWindowTestSupport.swift', 'TKNodePropertyPatchTests.swift', 'TKHierarchyDetailsAvailabilityTests.swift']
spec = {
 'name': 'SP270LookinValidation',
 'options': {'bundleIdPrefix':'dev.tritonkit.sp270', 'deploymentTarget':{'iOS':'15.0'}},
 'settings': {'base': {'SWIFT_VERSION':'5.0','CODE_SIGNING_ALLOWED':'NO','GENERATE_INFOPLIST_FILE':'YES'}},
 'packages': {'TritonKit': {'path': str(repo)}},
 'targets': {
  'LookinHost': {'type':'application','platform':'iOS','sources':[str(repo/'Examples/TritonKitTestFixture/RuntimeTestHost')], 'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'dev.tritonkit.sp270.host','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UILaunchScreen_Generation':'YES'}}},
  'LookinFixture': {'type':'application','platform':'iOS','sources':[str(fixture)], 'dependencies':[{'package':'TritonKit','product':'TritonKit'}], 'settings':{'base':{'PRODUCT_BUNDLE_IDENTIFIER':'dev.tritonkit.sp270.fixture','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_NSLocalNetworkUsageDescription':'Local inspection fixture','INFOPLIST_KEY_NSAppTransportSecurity_NSAllowsArbitraryLoads':'YES'}}},
  'LookinCoreTests': {'type':'bundle.unit-test','platform':'iOS','sources':[str(repo/'Tests/TritonKitTests'/name) for name in tests], 'dependencies':[{'target':'LookinHost'},{'package':'TritonKit','product':'TritonKit'},{'package':'TritonKit','product':'TritonKitShared'}], 'settings':{'base':{'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/LookinHost.app/LookinHost','BUNDLE_LOADER':'$(TEST_HOST)','PRODUCT_BUNDLE_IDENTIFIER':'dev.tritonkit.sp270.tests'},'configs':{'Debug':{'SWIFT_ACTIVE_COMPILATION_CONDITIONS':'$(inherited) DEBUG TRITONKIT_RUNTIME_ENABLED'}}}}
 },
 'schemes': {'LookinCore': {'build':{'targets':{'LookinHost':'all','LookinCoreTests':['test']}},'test':{'targets':[{'name':'LookinCoreTests','parallelizable':False}],'gatherCoverageData':False}}, 'LookinFixture': {'build':{'targets':{'LookinFixture':'all'}}}}
}
p=out/'project.json'; p.write_text(json.dumps(spec,indent=2)+'\n');print(p)
