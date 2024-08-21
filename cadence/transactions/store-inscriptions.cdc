import "Fixes"
import "FixesInscriptionFactory"

transaction(
    insIds: [UInt64]
) {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        let archiveIdxPath = Fixes.getArchivedFixesMaxIndexStoragePath()
        let archiveIdx = acct.storage.load<UInt64>(from: archiveIdxPath)
        if archiveIdx == nil {
            acct.storage.save<UInt64>(0, to: archiveIdxPath)
        }

        let archivePath = Fixes.getArchivedFixesStoragePath(archiveIdx ?? 0)
        if acct.storage.borrow<&Fixes.ArchivedInscriptions>(from: archivePath) == nil {
            acct.storage.save<@Fixes.ArchivedInscriptions>(<- Fixes.createArchivedInscriptions(), to: archivePath)
        }
        let archiveRef = acct
            .storage.borrow<auth(Fixes.Manage) &Fixes.ArchivedInscriptions>(from: archivePath)
            ?? panic("Could not borrow a reference to the Archived Inscriptions!")

        for insId in insIds {
            let insPath = Fixes.getFixesStoragePath(index: insId)
            if let insRef = acct.storage.borrow<&Fixes.Inscription>(from: insPath) {
                if !insRef.isExtracted() {
                    continue
                }
                if let ins <- acct.storage.load<@Fixes.Inscription>(from: insPath) {
                    archiveRef.archive(<- ins)
                    let isFull = archiveRef.isFull()
                    if isFull {
                        acct.storage.save<UInt64>(archiveIdx! + 1, to: archiveIdxPath)
                        break
                    }
                }
            }
        }
    }
}
