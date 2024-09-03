import "Fixes"

access(all)
fun main(
    addr: Address,
    page: Int,
    limit: Int,
): [Inscription] {
    let acct = getAuthAccount<auth(Storage, Capabilities) &Account>(addr)
    let storePath = Fixes.getFixesStoreStoragePath()
    if let storeRef = acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath) {
        let ids = storeRef.getIDs()
        var upTo = (page + 1) * limit
        if upTo > ids.length {
            upTo = ids.length
        }
        let slicedIds = ids.slice(from: page * limit, upTo: upTo)
        var ret: [Inscription] = []
        for id in slicedIds {
            if let ins = storeRef.borrowInscription(id) {
                ret.append(Inscription(
                    owner: addr,
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
