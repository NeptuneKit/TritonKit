import Foundation

enum TKDevicectlJSONFixtures {
    static let xcode26AvailablePaired = Data(
        #"""
        {
          "info": {
            "jsonVersion": 3,
            "outcome": "success",
            "version": "000.00000.00"
          },
          "result": {
            "devices": [
              {
                "identifier": "COREDEVICE-AVAILABLE-PAIRED",
                "deviceProperties": {
                  "name": "Fixture iPhone",
                  "osVersionNumber": "26.5.2",
                  "developerModeStatus": "enabled",
                  "ddiServicesAvailable": false,
                  "developerDiskImageMounted": false,
                  "lockState": "unlocked"
                },
                "hardwareProperties": {
                  "udid": "FIXTURE-DEVICE-UDID",
                  "serialNumber": "FIXTURE-SERIAL"
                },
                "connectionProperties": {
                  "transportType": "wired",
                  "pairingState": "paired",
                  "tunnelState": "disconnected",
                  "trusted": true
                },
                "visibilityClass": "default"
              }
            ]
          }
        }
        """#.utf8
    )

    static let explicitDDIMissing = Data(
        #"""
        {
          "info": { "jsonVersion": 3, "outcome": "success" },
          "result": {
            "devices": [
              {
                "identifier": "COREDEVICE-DDI-MISSING",
                "deviceProperties": {
                  "name": "Fixture DDI Missing",
                  "osVersionNumber": "26.5.2",
                  "developerModeStatus": "enabled",
                  "ddiStatus": "missing",
                  "lockState": "unlocked"
                },
                "connectionProperties": {
                  "transportType": "wired",
                  "pairingState": "paired",
                  "tunnelState": "connected"
                },
                "visibilityClass": "default"
              }
            ]
          }
        }
        """#.utf8
    )

    static let unpaired = Data(
        #"""
        {
          "info": { "jsonVersion": 3, "outcome": "success" },
          "result": {
            "devices": [
              {
                "identifier": "COREDEVICE-UNPAIRED",
                "deviceProperties": {
                  "name": "Fixture Unpaired",
                  "osVersionNumber": "26.5.2",
                  "developerModeStatus": "enabled",
                  "lockState": "unlocked"
                },
                "connectionProperties": {
                  "transportType": "wired",
                  "pairingState": "unpaired",
                  "tunnelState": "disconnected"
                },
                "visibilityClass": "default"
              }
            ]
          }
        }
        """#.utf8
    )

    static let disconnected = Data(
        #"""
        {
          "info": { "jsonVersion": 3, "outcome": "success" },
          "result": {
            "devices": [
              {
                "identifier": "COREDEVICE-DISCONNECTED",
                "deviceProperties": {
                  "name": "Fixture Disconnected",
                  "osVersionNumber": "26.5.2",
                  "developerModeStatus": "enabled",
                  "lockState": "unlocked"
                },
                "connectionProperties": {
                  "transportType": "wired",
                  "pairingState": "unknown",
                  "tunnelState": "disconnected"
                },
                "visibilityClass": "default"
              }
            ]
          }
        }
        """#.utf8
    )
}
