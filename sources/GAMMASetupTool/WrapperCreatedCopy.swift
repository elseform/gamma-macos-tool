enum SetupFlowCopy {
    static let wrapperDescription = "Create a Sikarugir Wine wrapper for your GAMMA installation."
}

enum WrapperCreatedCopy {
    static let title = "Wrapper ready"
    static let subtitle = "Application created successfully"
}

enum SetupOptionCopy {
    static let installAction = "Install"
    static let installBundledAction = "Update binaries"
    static let gptkBinaries = "GPTK4 beta 1 D3DMetal binaries"
    static let usvfsBinaries = "Update ModOrganizer usvfs libraries"
    static let logTitle = "Setup log"
    static let logAction = "Save"

    static var installGPTK4Binaries: String {
        gptkBinaries
    }

    static var installUSVFSBinaries: String {
        usvfsBinaries
    }

    static var saveDetailedLog: String {
        "Save setup log"
    }
}
