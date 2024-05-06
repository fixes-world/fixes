import "FRC20AccountsPool"
import "FixesFungibleTokenInterface"
import "FixesTradablePool"

access(all)
fun main(): UFix64 {
    // singleton resource and constants
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()

    // dictionary of addresses
    let addrsDict = acctsPool.getAddresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
    var totalTVL = 0.0
    addrsDict.forEachKey(fun (key: String): Bool {
        if let addr = addrsDict[key] {
            if let tradablePool = FixesTradablePool.borrowTradablePool(addr) {
                totalTVL = totalTVL + tradablePool.getBurnedLiquidityValue()
            }
        }
        return true
    })
    return totalTVL
}
