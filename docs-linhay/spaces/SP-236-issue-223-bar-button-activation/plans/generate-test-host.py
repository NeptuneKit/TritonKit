#!/usr/bin/env python3
"""Generate an ignored App-hosted UIKit test project; requires local xcodegen."""
import json
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[4]
output = root / '.build/issue-tests-host'
output.mkdir(parents=True, exist_ok=True)
(output/'App.swift').write_text('import SwiftUI\n@main struct IssueHost: App { var body: some Scene { WindowGroup { Text("Issue regression host") } } }\n')
files = ['TKUIKitWindowTestSupport.swift', 'TKRuntimeBarButtonTests.swift', 'TKSearchBarInputFocusTests.swift']
spec = {
 'name': 'IssueHost', 'options': {'deploymentTarget': {'iOS': '17.0'}},
 'packages': {'TritonKit': {'path': str(root)}},
 'settings': {'base': {'CODE_SIGNING_ALLOWED': 'NO', 'GENERATE_INFOPLIST_FILE': 'YES'}},
 'targets': {
  'IssueHost': {'type': 'application', 'platform': 'iOS', 'sources': ['App.swift'], 'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': 'com.neptunekit.issuehost', 'INFOPLIST_KEY_UIApplicationSceneManifest_Generation': 'YES', 'INFOPLIST_KEY_UILaunchScreen_Generation': 'YES'}}},
  'IssueTests': {'type': 'bundle.unit-test', 'platform': 'iOS', 'sources': [str(root/'Tests/TritonKitTests'/f) for f in files], 'dependencies': [{'target': 'IssueHost'}, {'package': 'TritonKit', 'product': 'TritonKit'}, {'package': 'TritonKit', 'product': 'TritonKitShared'}], 'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': 'com.neptunekit.issuetests', 'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/IssueHost.app/IssueHost', 'BUNDLE_LOADER': '$(TEST_HOST)', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG TRITONKIT_RUNTIME_ENABLED'}}}},
 'schemes': {'IssueHost': {'build': {'targets': {'IssueHost': 'all', 'IssueTests': 'test'}}, 'test': {'targets': ['IssueTests']}}}}
(output/'project.json').write_text(json.dumps(spec, indent=2))
subprocess.run(['xcodegen','generate','--spec',str(output/'project.json')],check=True)
print('Use triton xcode test --project .build/issue-tests-host/IssueHost.xcodeproj --scheme IssueHost with an explicitly selected Simulator.')
