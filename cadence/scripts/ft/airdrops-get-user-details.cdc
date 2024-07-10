import "FungibleToken"
// Fixes Imports
import "FixesTokenAirDrops"

access(all)
fun main(
    ftAddr: Address,
    userAddr: Address,
): UserAirdropStatus {
    if let pool = FixesTokenAirDrops.borrowAirdropPool(ftAddr) {
        return UserAirdropStatus(
            pool.getClaimableTokenAmount(userAddr)
        )
    }
    return UserAirdropStatus(0.0)
}

access(all) struct UserAirdropStatus {
    access(all) let claimableTokenAmount: UFix64

    init(
        _ claimableAmount: UFix64
    ) {
        self.claimableTokenAmount = claimableAmount
    }
}
