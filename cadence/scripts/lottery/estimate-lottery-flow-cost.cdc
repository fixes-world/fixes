import "FGameLotteryFactory"

access(all)
fun main(
    address: Address,
    ticketAmt: UInt8,
    powerupLv: UInt8,
    forMinting: Bool
): UFix64 {
    let powerupType = FGameLotteryFactory.PowerUpType(rawValue: powerupLv) ?? panic("Invalid powerup level")
    return forMinting
        ? FGameLotteryFactory.getFIXESMintingLotteryFlowCost(ticketAmt, powerupType)
        : FGameLotteryFactory.getFIXESLotteryFlowCost(ticketAmt, powerupType, address)

}
