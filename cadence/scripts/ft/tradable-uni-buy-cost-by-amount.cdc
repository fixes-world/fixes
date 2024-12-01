// Fixes Imports
import "FixesTradablePool"
import "FixesInscriptionFactory"

access(all)
fun main(
    ftAddr: Address,
    amount: UFix64,
): UFix64? {
    if let pool = FixesTradablePool.borrowTradablePool(ftAddr) {
        let tickerName = "$".concat(pool.getSymbol())
        let dataStr = FixesInscriptionFactory.buildPureExecuting(tick: tickerName, usage: "init", {})
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)
        return pool.getEstimatedBuyingCostByAmount(amount) + estimatedReqValue
    }
    return nil
}
