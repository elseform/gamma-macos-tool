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
    static let gptkBinaries = "GPTK4 D3DMetal binaries"
    static let dxBinaries = "DirectX Binaries"
    static let dxmtBinaries = "Latest DXMT libraries"
    static let usvfsBinaries = "Update ModOrganizer USVFS"
    static let logTitle = "Setup log"
    static let logAction = "Save"

    static var installGPTK4Binaries: String {
        "Install GPTK4 D3DMetal binaries"
    }

    static var installDXMTBinaries: String {
        dxmtBinaries
    }

    static var installUSVFSBinaries: String {
        usvfsBinaries
    }

    static var installDirectXBinaries: String {
        "Install DirectX Binaries locally (Skip winetricks directx9)"
    }

    static var saveDetailedLog: String {
        "Save setup log"
    }
}
