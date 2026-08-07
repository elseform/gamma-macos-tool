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
run("testDefaultOutputAppPathUsesApplicationsFolder", config.testDefaultOutputAppPathUsesApplicationsFolder)
run("testWrapperNameValidationRejectsUnsafeNames", config.testWrapperNameValidationRejectsUnsafeNames)
run("testRendererLabels", config.testRendererLabels)
run("testEnvironmentOKRequiresSelectedModOrganizerOnly", config.testEnvironmentOKRequiresSelectedModOrganizerOnly)
run("testCanInstallComponentsIsDisabledForWizard", config.testCanInstallComponentsIsDisabledForWizard)
run("testSetupRequestIncludesTargetAndRenderer", config.testSetupRequestIncludesTargetAndRenderer)
run("testDefaultsMatchPlaytestedSikarugirWrapper", config.testDefaultsMatchPlaytestedSikarugirWrapper)
run("testSetupRequestIncludesUSVFSUpdateOption", config.testSetupRequestIncludesUSVFSUpdateOption)
run("testSetupRequestIncludesGPTK4Option", config.testSetupRequestIncludesGPTK4Option)
run("testSetupRequestIncludesManualModOrganizerWhenProvided", config.testSetupRequestIncludesManualModOrganizerWhenProvided)
run("testCreateFlowRequiresSelectedModOrganizerButNotAutomaticGammaDiscovery", config.testCreateFlowRequiresSelectedModOrganizerButNotAutomaticGammaDiscovery)
run("testLaunchExecutableDefaultsToDetectedModOrganizer", config.testLaunchExecutableDefaultsToDetectedModOrganizer)
run("testCustomLaunchExecutableIsSerializedWithEnvironmentChoice", config.testCustomLaunchExecutableIsSerializedWithEnvironmentChoice)
run("testEmptyLaunchArgumentsAreNotSerialized", config.testEmptyLaunchArgumentsAreNotSerialized)
run("testCustomLaunchExecutableMustStillExist", config.testCustomLaunchExecutableMustStillExist)
run("testCustomModOrganizerLaunchRequestsEnvironment", config.testCustomModOrganizerLaunchRequestsEnvironment)
run("testSetupRequestIncludesDisplayResolutionOptions", config.testSetupRequestIncludesDisplayResolutionOptions)
run("testEngineLabels", config.testEngineLabels)
run("testSetupRequestIncludesVerboseLogOption", config.testSetupRequestIncludesVerboseLogOption)
run("testDriveMappingShortenMode", config.testDriveMappingShortenMode)
run("testDriveMappingIsReadyWhenPreflightContextIsAbsent", config.testDriveMappingIsReadyWhenPreflightContextIsAbsent)
run("testEnvironmentMessagesForMissingInputs", config.testEnvironmentMessagesForMissingInputs)

let engine = SetupEngineCoreTests()
run("testAppendWordsSplitsSpacesAndCommas", engine.testAppendWordsSplitsSpacesAndCommas)
run("testWinetricksVerbSupportRequiresEveryExactVerb", engine.testWinetricksVerbSupportRequiresEveryExactVerb)
run("testWinetricksCachesAreSharedAcrossWrappers", engine.testWinetricksCachesAreSharedAcrossWrappers)
run("testWinetricksCurrentVCRunChecksumsReplaceStaleValues", engine.testWinetricksCurrentVCRunChecksumsReplaceStaleValues)
run("testPathHelpers", engine.testPathHelpers)
run("testRegistryKeyValueEditorUpdatesSection", engine.testRegistryKeyValueEditorUpdatesSection)
run("testRegistryRawLineEditorUpdatesSection", engine.testRegistryRawLineEditorUpdatesSection)
run("testRegistryKeyValueEditorCreatesMissingSection", engine.testRegistryKeyValueEditorCreatesMissingSection)
run("testRequiredDllOverridesMatchEnforcedWrapperRegistry", engine.testRequiredDllOverridesMatchEnforcedWrapperRegistry)
run("testEnginePreflightReportsManualMO2Fixture", engine.testEnginePreflightReportsManualMO2Fixture)
run("testEnginePreflightLoadsStalkerGammaSettingsJSON", engine.testEnginePreflightLoadsStalkerGammaSettingsJSON)
run("testEnginePreflightReportsMissingSettingsWithoutFailing", engine.testEnginePreflightReportsMissingSettingsWithoutFailing)
run("testEnginePreflightReportsOptionalGRootWithoutRequiringRewrite", engine.testEnginePreflightReportsOptionalGRootWithoutRequiringRewrite)
run("testDryRunCreateAcceptsTemplateDriveCSymlink", engine.testDryRunCreateAcceptsTemplateDriveCSymlink)
run("testUSVFSDefaultSourceIsNotUserSpecific", engine.testUSVFSDefaultSourceIsNotUserSpecific)
run("testLaunchBatchEnvironmentIsOnlyAddedForModOrganizer", engine.testLaunchBatchEnvironmentIsOnlyAddedForModOrganizer)
run("testModOrganizerBatchUsesWindowsWorkingDirectory", engine.testModOrganizerBatchUsesWindowsWorkingDirectory)
run("testLaunchArgumentsRejectLineBreaks", engine.testLaunchArgumentsRejectLineBreaks)
run("testDefaultModOrganizerBatchDetectionIsNarrow", engine.testDefaultModOrganizerBatchDetectionIsNarrow)
run("testDefaultInstallUsesWineZMappingWithoutCreatingShortDrive", engine.testDefaultInstallUsesWineZMappingWithoutCreatingShortDrive)
run("testAdvancedInstallCreatesGMappingWithoutChangingModOrganizerINI", engine.testAdvancedInstallCreatesGMappingWithoutChangingModOrganizerINI)
run("testCustomLaunchBatchesUseMappedGAndFallbackZPaths", engine.testCustomLaunchBatchesUseMappedGAndFallbackZPaths)
run("testExistingTargetIsRejectedWithoutReplacement", engine.testExistingTargetIsRejectedWithoutReplacement)
run("testWinetricksDetectionReadsRegistryDllOverrides", engine.testWinetricksDetectionReadsRegistryDllOverrides)
run("testUSVFSInstallerComparesAndReplacesStaleBinaries", engine.testUSVFSInstallerComparesAndReplacesStaleBinaries)
run("testGPTK4PayloadDetectionAndReplacement", engine.testGPTK4PayloadDetectionAndReplacement)
run("testConfigureAliasCreationAndCollisionHandling", engine.testConfigureAliasCreationAndCollisionHandling)

let appSettings = AppSettingsStoreTests()
run("testManualGammaSelectionFindsDirectModOrganizer", appSettings.testManualGammaSelectionFindsDirectModOrganizer)
run("testManualGammaSelectionFindsNestedModOrganizer", appSettings.testManualGammaSelectionFindsNestedModOrganizer)
run("testManualGammaSelectionRejectsInvalidFolder", appSettings.testManualGammaSelectionRejectsInvalidFolder)
run("testModOrganizerValidationRequiresExecutableNameAndFile", appSettings.testModOrganizerValidationRequiresExecutableNameAndFile)
run("testAppSettingsSaveAndLoadManualModOrganizerPath", appSettings.testAppSettingsSaveAndLoadManualModOrganizerPath)
run("testAppSettingsLoadIgnoresMissingAndMalformedFiles", appSettings.testAppSettingsLoadIgnoresMissingAndMalformedFiles)

let tones = SetupStatusToneTests()
run("testCheckRowTonesMatchEnvironmentColoringRules", tones.testCheckRowTonesMatchEnvironmentColoringRules)
run("testStatusRowTonesMatchCheckRows", tones.testStatusRowTonesMatchCheckRows)
run("testWinetricksTonesMatchWrapperState", tones.testWinetricksTonesMatchWrapperState)

if failures.isEmpty {
    print("\nAll Swift tests passed.")
} else {
    for failure in failures {
        print(failure)
    }
    exit(1)
}
