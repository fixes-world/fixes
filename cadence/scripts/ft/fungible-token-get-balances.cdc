import "StringUtils"
import "FTViewUtils"
// Fixes Imports
import "FixesTraits"
import "FixesFungibleTokenInterface"
import "FungibleTokenManager"

access(all)
fun main(
    userAddr: Address,
    ftAddrs: [Address],
    includeInfo: Bool
): [BalanceResult] {
    let results: [BalanceResult] = []
    for ftAddr in ftAddrs {
        let ftAcct = getAccount(ftAddr)
        var info: FungibleTokenManager.FixesTokenInfo? = nil
        var ftContractName = "FixesFungibleToken"
        var ftContract: &FixesFungibleTokenInterface? = nil
        if includeInfo {
            info = FungibleTokenManager.buildFixesTokenInfo(ftAddr, nil)
            if info != nil {
                ftContractName = info!.view.standardView.identity.contractName
            } else {
                continue
            }
            ftContract = ftAcct.contracts.borrow<&FixesFungibleTokenInterface>(name: ftContractName)
        } else {
            ftContract = ftAcct.contracts.borrow<&FixesFungibleTokenInterface>(name: ftContractName)
            if ftContract == nil {
                ftContractName = "FRC20FungibleToken"
                ftContract = ftAcct.contracts.borrow<&FixesFungibleTokenInterface>(name: ftContractName)
            }
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
                identity: FTViewUtils.FTIdentity(ftAddr, ftContractName),
                balance: metadata.balance,
                info: info,
                metadata: mappedMergeableData
            ))
        }
    }
    return results
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
