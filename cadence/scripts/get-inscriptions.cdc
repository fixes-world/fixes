import "Fixes"

pub fun main(
    addr: Address
): [Inscription] {
    let acct = getAuthAccount(addr)

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
            }
        }
        return true
    })
    return ret
}

pub struct Inscription {
    pub let id: UInt64
    pub let parentId: UInt64?
    pub let owner: Address
    pub let value: UFix64
    pub let rarity: UInt8
    // content
    pub let createdAt: UFix64;
    pub let mimeType: String
    pub let protocol: String?;
    pub let encoding: String?;
    pub let metadata: [UInt8];
    pub let dataStr: String?;

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
        self.dataStr = data.encoding == nil || data.encoding == "utf8" ? String.fromUTF8(data.metadata) : ""
    }
}
