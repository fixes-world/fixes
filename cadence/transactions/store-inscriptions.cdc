import "Fixes"
import "FixesInscriptionFactory"

transaction(
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

        let paths: [StoragePath] = []
        let limit = 500
        var i = 0
        acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
            if type == Type<@Fixes.Inscription>() {
                if let insRef = acct.borrow<&Fixes.Inscription>(from: path) {
                    if !insRef.isExtracted() {
                        return true
                    }
                    paths.append(path)
                    if i > limit {
                        return false
                    }
                }
            }
            return true
        })
        for path in paths {
            if let ins <- acct.load<@Fixes.Inscription>(from: path) {
                archiveRef.archive(<- ins)
                i = i + 1
                let isFull = archiveRef.isFull()
                if isFull {
                    acct.save<UInt64>(archiveIdx! + 1, to: archiveIdxPath)
                    break
                }
            }
        }
    }
}
