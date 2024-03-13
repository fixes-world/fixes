import "FGameLotteryFactory"

access(all)
fun main(
    address: Address,
    ticketAmt: UInt64,
    powerupLv: UInt8,
    forFlow: Bool,
    withMining: Bool
): UFix64 {
    let powerupType = FGameLotteryFactory.PowerUpType(rawValue: powerupLv) ?? panic("Invalid powerup level")
    return forFlow
        ? FGameLotteryFactory.getFIXESMintingLotteryFlowCost(ticketAmt, powerupType, withMining)
        : FGameLotteryFactory.getFIXESLotteryFlowCost(ticketAmt, powerupType, address)

}
