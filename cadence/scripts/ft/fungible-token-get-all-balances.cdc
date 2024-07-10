import "StringUtils"
import "FTViewUtils"
// Fixes Imports
import "FixesTraits"
import "FixesFungibleTokenInterface"
import "FungibleTokenManager"

access(all)
fun main(
    userAddr: Address,
    includeInfo: Bool
): [BalanceResult] {
    log("Getting balances for user: ".concat(userAddr.toString()))
    // search for all fungible tokens with FixesFungibleTokenInterface
    let acct = getAuthAccount(userAddr)

    let identifiers: [FTViewUtils.FTIdentity] = []
    acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
        // log("Checking at storage: ".concat(path.toString()))
        if type.isSubtype(of: Type<@FixesFungibleTokenInterface.Vault>()) {
            log("Found fungible token: ".concat(type.identifier))
            if let id = parseIdentity(type.identifier) {
                identifiers.append(id)
            }
        }
        return true
    })

    // log("Found ".concat(identifiers.length.toString()).concat(" fungible tokens"))

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
        if let metadata = ftContract!.borrowTokenMetadata(userAddr) {
            let mappedMergeableData: {String: {FixesTraits.MergeableData}} = {}
            let keys = metadata.getMergeableKeys()
            for key in keys {
                if let mergeableData = metadata.getMergeableData(key) {
                    let ids = StringUtils.split(key.identifier, ".")
                    mappedMergeableData[ids[3]] = mergeableData
                }
            }
            results.append(BalanceResult(
                identity: id,
                balance: metadata.balance,
                info: info,
                metadata: mappedMergeableData
            ))
        }
    }
    return results
}

access(all)
fun parseIdentity(_ identifier: String): FTViewUtils.FTIdentity? {
    let ids = StringUtils.split(identifier, ".")
    assert(ids.length == 4, message: "Invalid type identifier!")
    if let addr = Address.fromString("0x".concat(ids[1])) {
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
    access(all)
    let metadata: {String: {FixesTraits.MergeableData}}
    init(
        identity: FTViewUtils.FTIdentity,
        balance: UFix64,
        info: FungibleTokenManager.FixesTokenInfo?,
        metadata: {String: {FixesTraits.MergeableData}}?
    ) {
        self.identity = identity
        self.balance = balance
        self.info = info
        self.metadata = metadata ?? {}
    }
}
