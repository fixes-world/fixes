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
    pub let owner: Address
    pub let id: UInt64
    pub let data: Fixes.InscriptionData
    pub let value: UFix64
    pub let rarity: UInt8
    pub let parentId: UInt64?

    init(
        owner: Address,
        id: UInt64,
        data: Fixes.InscriptionData,
        value: UFix64,
        rarity: UInt8,
        parentId: UInt64?
    ) {
        self.owner = owner
        self.id = id
        self.data = data
        self.value = value
        self.rarity = rarity
        self.parentId = parentId
    }
}
