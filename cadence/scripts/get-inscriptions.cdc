import "Fixes"

access(all)
fun main(
    addr: Address,
): [Inscription] {
    let acct = getAuthAccount(addr)

    let limit = 500
    var i = 0
    let ret: [Inscription] = []
    acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
        if type == Type<@Fixes.Inscription>() {
            if let ins = acct.borrow<&Fixes.Inscription>(from: path) {
                ret.append(Inscription(
                    owner: addr,
                    id: ins.getId(),
                    data: ins.getData(),
                    value: ins.getInscriptionValue(),
                    rarity: ins.getInscriptionRarity().rawValue,
                    parentId: ins.getParentId()
                ))
                i = i + 1
                if i > limit {
                    return false
                }
            }
        }
        return true
    })
    return ret
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
