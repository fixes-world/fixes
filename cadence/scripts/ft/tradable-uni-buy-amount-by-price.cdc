// Fixes Imports
import "FixesTradablePool"
import "FixesInscriptionFactory"

access(all)
fun main(
    ftAddr: Address,
    cost: UFix64,
): UFix64? {
    if let pool = FixesTradablePool.borrowTradablePool(ftAddr) {
        let tickerName = "$".concat(pool.getSymbol())
        let dataStr = FixesInscriptionFactory.buildPureExecuting(tick: tickerName, usage: "init", {})
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)
        if estimatedReqValue > cost {
            return 0.0
        }
        return pool.getEstimatedBuyingAmountByCost(cost - estimatedReqValue)
    }
    return nil
}
