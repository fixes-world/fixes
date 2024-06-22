import "StringUtils"
import "FTViewUtils"
// Fixes Imports
import "FixesFungibleTokenInterface"
import "FungibleTokenManager"

access(all)
fun main(
    userAddr: Address,
    includeInfo: Bool
): [BalanceResult] {
    // search for all fungible tokens with FixesFungibleTokenInterface
    let acct = getAuthAccount(userAddr)

    let identifiers: [FTViewUtils.FTIdentity] = []
    acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
        if type.isSubtype(of: Type<@FixesFungibleTokenInterface.Vault>()) {
            if let id = parseIdentity(type.identifier) {
                identifiers.append(id)
            }
        }
        return true
    })

    let results: [BalanceResult] = []
    for id in identifiers {
        let ftAcct = getAccount(id.address)
        let ftContractName = id.contractName
        var ftContract = ftAcct.contracts.borrow<&FixesFungibleTokenInterface>(name: ftContractName)
        var info: FungibleTokenManager.FixesTokenInfo? = nil
        if includeInfo {
            info = FungibleTokenManager.buildFixesTokenInfo(id.address, nil)
        }
        if ftContract == nil {
            continue
        }
        let balance = ftContract!.getTokenBalance(userAddr)
        results.append(BalanceResult(
            identity: id,
            balance: balance,
            info: info
        ))
    }
    return results
}

access(all)
fun parseIdentity(_ identifier: String): FTViewUtils.FTIdentity? {
    let ids = StringUtils.split(identifier, ".")
    assert(ids.length == 4, message: "Invalid type identifier!")
    if let addr = Address.fromString(ids[1]) {
        return FTViewUtils.FTIdentity(addr, ids[2])
    }
    return nil
}

access(all) struct BalanceResult {
    access(all)
    let identity: FTViewUtils.FTIdentity
    access(all)
    let balance: UFix64
    access(all)
    let info: FungibleTokenManager.FixesTokenInfo?
    init(
        identity: FTViewUtils.FTIdentity,
        balance: UFix64,
        info: FungibleTokenManager.FixesTokenInfo?
    ) {
        self.identity = identity
        self.balance = balance
        self.info = info
    }
}
