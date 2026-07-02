import Foundation

struct TestFailure: Error, CustomStringConvertible {
    var description: String
}

func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    if actual != expected {
        recordFailure("expected \(expected), got \(actual)", file: file, line: line)
    }
}

func XCTAssertTrue(_ condition: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    if !condition() {
        recordFailure("expected true", file: file, line: line)
    }
}

func XCTAssertFalse(_ condition: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    if condition() {
        recordFailure("expected false", file: file, line: line)
    }
}

func XCTAssertNil<T>(_ value: @autoclosure () -> T?, file: StaticString = #file, line: UInt = #line) {
    if let value = value() {
        recordFailure("expected nil, got \(value)", file: file, line: line)
    }
}

func XCTAssertNotNil<T>(_ value: @autoclosure () -> T?, file: StaticString = #file, line: UInt = #line) {
    if value() == nil {
        recordFailure("expected non-nil", file: file, line: line)
    }
}

func XCTAssertContains(_ value: String, _ expectedSubstring: String, file: StaticString = #file, line: UInt = #line) {
    if !value.contains(expectedSubstring) {
        recordFailure("expected \(value) to contain \(expectedSubstring)", file: file, line: line)
    }
}

private var failures: [String] = []

func recordFailure(_ message: String, file: StaticString, line: UInt) {
    failures.append("\(file):\(line): \(message)")
}

func run(_ name: String, _ body: () throws -> Void) {
    let before = failures.count
    do {
        try body()
    } catch {
        failures.append("\(name): threw \(error)")
    }
    if failures.count == before {
        print("ok - \(name)")
    } else {
        print("not ok - \(name)")
    }
}

let config = SetupConfigurationTests()
run("testOutputAppPathAddsAppSuffix", config.testOutputAppPathAddsAppSuffix)
run("testOutputAppPathDoesNotDuplicateAppSuffix", config.testOutputAppPathDoesNotDuplicateAppSuffix)
run("testRendererLabels", config.testRendererLabels)
run("testEnvironmentOKRequiresAllRequiredInputs", config.testEnvironmentOKRequiresAllRequiredInputs)
run("testCanInstallComponentsOnlyWhenBrewManagedDependenciesAreMissing", config.testCanInstallComponentsOnlyWhenBrewManagedDependenciesAreMissing)
run("testSetupRequestIncludesTargetAndRenderer", config.testSetupRequestIncludesTargetAndRenderer)
run("testDefaultsMatchPlaytestedSikarugirWrapper", config.testDefaultsMatchPlaytestedSikarugirWrapper)
run("testSetupRequestIncludesWineSyncOptions", config.testSetupRequestIncludesWineSyncOptions)
run("testSetupRequestIncludesHIDDevicesOption", config.testSetupRequestIncludesHIDDevicesOption)
run("testSetupRequestIncludesFnToggleOption", config.testSetupRequestIncludesFnToggleOption)
run("testSetupRequestIncludesUSVFSUpdateOption", config.testSetupRequestIncludesUSVFSUpdateOption)
run("testSetupRequestIncludesManualModOrganizerWhenProvided", config.testSetupRequestIncludesManualModOrganizerWhenProvided)
run("testLaunchExecutableDefaultsToDetectedModOrganizer", config.testLaunchExecutableDefaultsToDetectedModOrganizer)
run("testCustomLaunchExecutableIsSerializedWithEnvironmentChoice", config.testCustomLaunchExecutableIsSerializedWithEnvironmentChoice)
run("testCustomModOrganizerLaunchRequestsEnvironment", config.testCustomModOrganizerLaunchRequestsEnvironment)
run("testSetupRequestIncludesDisplayResolutionOptions", config.testSetupRequestIncludesDisplayResolutionOptions)
run("testEngineLabels", config.testEngineLabels)
run("testD3DMetalSetupRequestOptions", config.testD3DMetalSetupRequestOptions)
run("testDXMTSetupRequestOptions", config.testDXMTSetupRequestOptions)
run("testDXVKSetupRequestOptionsRequireHUDToggleForHUDContents", config.testDXVKSetupRequestOptionsRequireHUDToggleForHUDContents)
run("testDriveMappingShortenMode", config.testDriveMappingShortenMode)
run("testEnvironmentMessagesForMissingInputs", config.testEnvironmentMessagesForMissingInputs)

let engine = SetupEngineCoreTests()
run("testAppendWordsSplitsSpacesAndCommas", engine.testAppendWordsSplitsSpacesAndCommas)
run("testWinetricksVerbSupportRequiresEveryExactVerb", engine.testWinetricksVerbSupportRequiresEveryExactVerb)
run("testPathHelpers", engine.testPathHelpers)
run("testRegistryKeyValueEditorUpdatesSection", engine.testRegistryKeyValueEditorUpdatesSection)
run("testRegistryRawLineEditorUpdatesSection", engine.testRegistryRawLineEditorUpdatesSection)
run("testRegistryKeyValueEditorCreatesMissingSection", engine.testRegistryKeyValueEditorCreatesMissingSection)
run("testEnginePreflightReportsManualMO2Fixture", engine.testEnginePreflightReportsManualMO2Fixture)
run("testEnginePreflightLoadsStalkerGammaSettingsJSON", engine.testEnginePreflightLoadsStalkerGammaSettingsJSON)
run("testEnginePreflightReportsMissingSettingsWithoutFailing", engine.testEnginePreflightReportsMissingSettingsWithoutFailing)
run("testEnginePreflightDetectsZRewriteRequirement", engine.testEnginePreflightDetectsZRewriteRequirement)
run("testDryRunCreateAcceptsTemplateDriveCSymlink", engine.testDryRunCreateAcceptsTemplateDriveCSymlink)
run("testUSVFSDefaultSourceIsNotUserSpecific", engine.testUSVFSDefaultSourceIsNotUserSpecific)
run("testLaunchBatchEnvironmentIsOnlyAddedForModOrganizer", engine.testLaunchBatchEnvironmentIsOnlyAddedForModOrganizer)
run("testModOrganizerBatchUsesWindowsWorkingDirectory", engine.testModOrganizerBatchUsesWindowsWorkingDirectory)
run("testDefaultModOrganizerBatchDetectionIsNarrow", engine.testDefaultModOrganizerBatchDetectionIsNarrow)
run("testDXMTCLICommandsReplaceManagedValuesAndPreserveOthers", engine.testDXMTCLICommandsReplaceManagedValuesAndPreserveOthers)

let appSettings = AppSettingsStoreTests()
run("testManualGammaSelectionFindsDirectModOrganizer", appSettings.testManualGammaSelectionFindsDirectModOrganizer)
run("testManualGammaSelectionFindsNestedModOrganizer", appSettings.testManualGammaSelectionFindsNestedModOrganizer)
run("testManualGammaSelectionRejectsInvalidFolder", appSettings.testManualGammaSelectionRejectsInvalidFolder)
run("testAppSettingsSaveAndLoadManualModOrganizerPath", appSettings.testAppSettingsSaveAndLoadManualModOrganizerPath)
run("testAppSettingsLoadIgnoresMissingAndMalformedFiles", appSettings.testAppSettingsLoadIgnoresMissingAndMalformedFiles)

let tones = SetupStatusToneTests()
run("testCheckRowTonesMatchEnvironmentColoringRules", tones.testCheckRowTonesMatchEnvironmentColoringRules)
run("testStatusRowTonesMatchCheckRows", tones.testStatusRowTonesMatchCheckRows)
run("testWinetricksTonesMatchWrapperState", tones.testWinetricksTonesMatchWrapperState)
run("testSetupControlToneHighlightsExistingWrapperSettings", tones.testSetupControlToneHighlightsExistingWrapperSettings)

if failures.isEmpty {
    print("\nAll Swift tests passed.")
} else {
    for failure in failures {
        print(failure)
    }
    exit(1)
}
