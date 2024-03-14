import "Fixes"
import "FixesInscriptionFactory"

transaction(
    insIds: [UInt64]
) {
    prepare(acct: AuthAccount) {
        let archiveIdxPath = Fixes.getArchivedFixesMaxIndexStoragePath()
        let archiveIdx = acct.load<UInt64>(from: archiveIdxPath)
        if archiveIdx == nil {
            acct.save<UInt64>(0 as UInt64, to: archiveIdxPath)
        }

        let archivePath = Fixes.getArchivedFixesStoragePath(archiveIdx ?? 0)
        if acct.borrow<&Fixes.ArchivedInscriptions>(from: archivePath) == nil {
            acct.save<@Fixes.ArchivedInscriptions>(<- Fixes.createArchivedInscriptions(), to: archivePath)
        }
        let archiveRef = acct.borrow<&Fixes.ArchivedInscriptions>(from: archivePath)
            ?? panic("Could not borrow a reference to the Archived Inscriptions!")

        for insId in insIds {
            let insPath = Fixes.getFixesStoragePath(index: insId)
            if let insRef = acct.borrow<&Fixes.Inscription>(from: insPath) {
                if !insRef.isExtracted() {
                    continue
                }
                if let ins <- acct.load<@Fixes.Inscription>(from: insPath) {
                    archiveRef.archive(<- ins)
                    let isFull = archiveRef.isFull()
                    if isFull {
                        acct.save<UInt64>(archiveIdx! + 1, to: archiveIdxPath)
                        break
                    }
                }
            }
        }
    }
}
