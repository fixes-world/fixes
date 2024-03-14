import "Fixes"

access(all)
fun main(
    addr: Address,
): ArchivedInfo {
    let acct = getAuthAccount(addr)
    let archiveIdxPath = Fixes.getArchivedFixesMaxIndexStoragePath()
    let archiveIdx = acct.load<UInt64>(from: archiveIdxPath) ?? 0

    let archivedAmount: [UInt64] = []
    var i: UInt64 = 0
    while i <= archiveIdx {
        let archivePath = Fixes.getArchivedFixesStoragePath(i)
        if let ref = acct.borrow<&Fixes.ArchivedInscriptions>(from: archivePath) {
            archivedAmount.append(UInt64(ref.getLength()))
        }
        i = i + 1
    }
    return ArchivedInfo(maxIndex: archiveIdx, archivedAmount: archivedAmount)
}

access(all) struct ArchivedInfo {
    access(all) let maxIndex: UInt64
    access(all) let archivedAmount: [UInt64]

    init(maxIndex: UInt64, archivedAmount: [UInt64]) {
        self.maxIndex = maxIndex
        self.archivedAmount = archivedAmount
    }
}
