enum SetupFlowCopy {
    static let wrapperDescription = "Create a Sikarugir Wine wrapper for your GAMMA installation."
}

enum WrapperCreatedCopy {
    static let title = "Wrapper ready"
    static let subtitle = "Your GAMMA app is ready to use."
}

enum SetupOptionCopy {
    static let installAction = "Install"
    static let installBundledAction = "Install bundled"
    static let gptkBinaries = "GPTK4 D3DMetal binaries"
    static let usvfsBinaries = "ModOrganizer usvfs binaries"
    static let logTitle = "Detailed setup log"
    static let logAction = "Save"

    static var installGPTK4Binaries: String {
        "\(installAction) \(gptkBinaries)"
    }

    static var installUSVFSBinaries: String {
        "\(installBundledAction) \(usvfsBinaries)"
    }

    static var saveDetailedLog: String {
        "Save detailed setup log"
    }
}
