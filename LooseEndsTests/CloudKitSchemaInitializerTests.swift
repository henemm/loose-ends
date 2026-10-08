import CoreData
import Foundation
import Testing
@testable import LooseEnds

/// The CloudKit Development schema only had what a record ever wrote with a value: three types and
/// eleven task fields were missing (#175, S0). The initializer creates the full schema from the model
/// before the deploy to Production. None of these tests talks to CloudKit.
@Suite("CloudKit schema initializer (#175)") struct CloudKitSchemaInitializerTests {
    @Test("The model handed to CloudKit holds all six entities")
    func modelHoldsAllEntities() {
        let model = CloudKitSchemaInitializer.makeModel()
        let names = Set(model.entitiesByName.keys)
        #expect(names == ["TaskItem", "TaskContext", "Project", "Revision", "CompletionRecord", "SavedView"])
    }

    @Test("The task entity carries the fields Development was missing")
    func taskCarriesMissingFields() throws {
        let task = try #require(CloudKitSchemaInitializer.makeModel().entitiesByName["TaskItem"])
        for attribute in ["placeRemindedAt", "repeatRule", "parkedAt", "sourceURL", "place", "calendarEventID"] {
            #expect(task.propertiesByName[attribute] != nil, "missing attribute \(attribute)")
        }
        #expect(task.relationshipsByName["project"] != nil)
        #expect(task.relationshipsByName["parent"] != nil)
    }

    @Test("The scratch store lives in the temporary directory, never in the app group or the factory's place")
    func scratchStoreIsIsolated() {
        let url = CloudKitSchemaInitializer.scratchStoreURL().standardizedFileURL.path
        let temporary = FileManager.default.temporaryDirectory.standardizedFileURL.path
        #expect(url.hasPrefix(temporary))
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ModelContainerFactory.appGroup) {
            #expect(!url.hasPrefix(group.standardizedFileURL.path))
        }
        let applicationSupport = URL.applicationSupportDirectory.standardizedFileURL.path
        #expect(!url.hasPrefix(applicationSupport))
    }

    @Test("Each run gets its own scratch place")
    func scratchStoreIsFresh() {
        #expect(CloudKitSchemaInitializer.scratchStoreURL() != CloudKitSchemaInitializer.scratchStoreURL())
    }

    @Test("Only the argument in a debug build outside tests starts the initializer",
          arguments: [true, false], [true, false])
    func startDecision(isDebugBuild: Bool, isTestRun: Bool) {
        let with = ["LooseEnds", CloudKitSchemaInitializer.launchArgument]
        let without = ["LooseEnds"]
        #expect(CloudKitSchemaInitializer.shouldRun(arguments: with, isDebugBuild: isDebugBuild, isTestRun: isTestRun)
                == (isDebugBuild && !isTestRun))
        #expect(!CloudKitSchemaInitializer.shouldRun(arguments: without, isDebugBuild: isDebugBuild, isTestRun: isTestRun))
    }

    @Test("The argument has the name the operation docs use")
    func argumentName() {
        #expect(CloudKitSchemaInitializer.launchArgument == "-LEInitializeCloudKitSchema")
    }
}
