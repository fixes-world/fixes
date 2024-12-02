import "FGameLotteryFactory"

access(all)
fun main(
    coinAddr: Address,
    flowAmount: UFix64,
): FGameLotteryFactory.CoinTicketEstimate? {
    return FGameLotteryFactory.estimateButTokenWithTickets(coinAddr, flowAmount: flowAmount)
}
