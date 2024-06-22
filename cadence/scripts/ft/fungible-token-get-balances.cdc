import "FTViewUtils"
// Fixes Imports
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
        let balance = ftContract!.getTokenBalance(userAddr)
        results.append(BalanceResult(
            identity: FTViewUtils.FTIdentity(ftAddr, ftContractName),
            balance: balance,
            info: info
        ))
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
