import "Fixes"
import "FRC20Indexer"

access(all)
fun main(
    ids: [UInt64],
): [Inscription] {
    let frc20Indexer = FRC20Indexer.getIndexer()
    let systemAddr = frc20Indexer.owner!.address
    let acct = getAuthAccount(systemAddr)
    let storePath = Fixes.getFixesStoreStoragePath()
    if let storeRef = acct.borrow<&Fixes.InscriptionsStore>(from: storePath) {
        var ret: [Inscription] = []
        for id in ids {
            if let ins = storeRef.borrowInscription(id) {
                ret.append(Inscription(
                    owner: systemAddr,
                    id: ins.getId(),
                    data: ins.getData(),
                    value: ins.getInscriptionValue(),
                    rarity: ins.getInscriptionRarity().rawValue,
                    parentId: ins.getParentId()
                ))
            }
        }
        return ret
    }
    return []
}

access(all) struct Inscription {
    access(all) let id: UInt64
    access(all) let parentId: UInt64?
    access(all) let owner: Address
    access(all) let value: UFix64
    access(all) let rarity: UInt8
    // content
    access(all) let createdAt: UFix64;
    access(all) let mimeType: String
    access(all) let protocol: String?;
    access(all) let encoding: String?;
    access(all) let metadata: [UInt8];

    init(
        owner: Address,
        id: UInt64,
        data: Fixes.InscriptionData,
        value: UFix64,
        rarity: UInt8,
        parentId: UInt64?
    ) {
        self.id = id
        self.parentId = parentId
        self.owner = owner
        self.value = value
        self.rarity = rarity

        self.createdAt = data.createdAt
        self.mimeType = data.mimeType
        self.protocol = data.metaProtocol
        self.encoding = data.encoding
        self.metadata = data.metadata
    }
}
