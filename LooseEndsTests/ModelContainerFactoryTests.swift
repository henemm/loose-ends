import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// App group and CloudKit container come from the bundle, so a probe build (#156) can carry its
/// own and never reach the production data.
@Suite("Model container identifiers") struct ModelContainerFactoryTests {
    @Test("Both keys present: the bundle's values are used")
    func readsBothKeys() {
        let ids = ModelContainerFactory.resolveIdentifiers(
            from: ["LEAppGroup": "group.x", "LECloudContainer": "iCloud.x"]
        )
        #expect(ids.group == "group.x")
        #expect(ids.container == "iCloud.x")
    }

    @Test("No info dictionary: today's production identifiers")
    func fallsBackWithoutDictionary() {
        let ids = ModelContainerFactory.resolveIdentifiers(from: nil)
        #expect(ids.group == "group.com.henning.looseends")
        #expect(ids.container == "iCloud.com.henning.looseends")
    }

    @Test("One key missing: that one falls back, the other is read")
    func mixedCase() {
        let ids = ModelContainerFactory.resolveIdentifiers(from: ["LEAppGroup": "group.x"])
        #expect(ids.group == "group.x")
        #expect(ids.container == "iCloud.com.henning.looseends")
    }

    @Test("The standard build carries the production identifiers in its Info.plist")
    func standardBuildKeepsProductionIdentifiers() {
        let info = Bundle.main.infoDictionary
        #expect(info?["LEAppGroup"] as? String == "group.com.henning.looseends")
        #expect(info?["LECloudContainer"] as? String == "iCloud.com.henning.looseends")
        #expect(ModelContainerFactory.appGroup == "group.com.henning.looseends")
        #expect(ModelContainerFactory.cloudContainer == "iCloud.com.henning.looseends")
    }

    @Test("The in-memory store of tests and UI tests never syncs with iCloud (#163)")
    func inMemoryStoreHasNoCloudKit() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let configuration = try #require(container.configurations.first)
        #expect(configuration.isStoredInMemoryOnly)
        #expect(String(describing: configuration.cloudKitDatabase) == String(describing: ModelConfiguration.CloudKitDatabase.none))
        #expect(String(describing: ModelConfiguration.CloudKitDatabase.none) != String(describing: ModelConfiguration.CloudKitDatabase.automatic),
                "the check above must be able to tell the two apart")
    }
}
