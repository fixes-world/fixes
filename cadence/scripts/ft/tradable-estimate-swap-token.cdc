import "FungibleToken"
import "SwapConfig"
// Fixes Imports
import "FixesTradablePool"
import "FRC20AccountsPool"

access(all)
fun main(
    accountKey: String,
    directionCoinToFlow: Bool,
    amountIn: UFix64,
): SwapEstimatedPreview? {
    let acctsPool = FRC20AccountsPool.borrowAccountsPool()
    if let ftAddr = acctsPool.getFTContractAddress(accountKey) {
        if let pool = FixesTradablePool.borrowTradablePool(ftAddr) {
            if pool.isLiquidityHandovered() {
                if let pairInfo = pool.getSwapPairReservedInfo() {
                    let reserveCoin = pairInfo[0]
                    let reserveFlow = pairInfo[1]
                    var amountOut = 0.0
                    if directionCoinToFlow {
                        amountOut = SwapConfig.getAmountOut(amountIn: amountIn, reserveIn: reserveCoin, reserveOut: reserveFlow)
                    } else {
                        amountOut = SwapConfig.getAmountOut(amountIn: amountIn, reserveIn: reserveFlow, reserveOut: reserveCoin)
                    }
                    return SwapEstimatedPreview(
                        isCoinToFlow: directionCoinToFlow,
                        amountIn: amountIn,
                        amountOut: UFix64(amountOut),
                        reservedCoin: reserveCoin,
                        reservedFlow: reserveFlow
                    )
                }
            }
        }
    }
    return nil
}

access(all) struct SwapEstimatedPreview {
    access(all) let isCoinToFlow: Bool
    access(all) let amountIn: UFix64
    access(all) let amountOut: UFix64
    access(all) let reservedCoin: UFix64
    access(all) let reservedFlow: UFix64

    init(
        isCoinToFlow: Bool,
        amountIn: UFix64,
        amountOut: UFix64,
        reservedCoin: UFix64,
        reservedFlow: UFix64
    ) {
        self.isCoinToFlow = isCoinToFlow
        self.amountIn = amountIn
        self.amountOut = amountOut
        self.reservedCoin = reservedCoin
        self.reservedFlow = reservedFlow
    }
}
