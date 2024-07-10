import "FungibleToken"
// Fixes Imports
import "FixesTokenLockDrops"

access(all)
fun main(
    ftAddr: Address,
    userAddr: Address,
): UserStatus {
    let center = FixesTokenLockDrops.borrowLockingCenter()
    if let pool = FixesTokenLockDrops.borrowDropsPool(ftAddr) {
        return UserStatus(
            center.isUserJoinedPool(ftAddr, userAddr),
            center.getLockedTokenBalance(ftAddr, userAddr),
            center.getUnlockedBalance(ftAddr, userAddr),
            pool.getClaimableTokenAmount(userAddr)
        )
    }
    return UserStatus(false, 0.0, 0.0, 0.0)
}

access(all) struct UserStatus {
    access(all) let isJoined: Bool
    access(all) let lockedTokenBalance: UFix64
    access(all) let unlockedTokenBalance: UFix64
    access(all) let claimableTokenAmount: UFix64

    init(
        _ isJoined: Bool,
        _ lockedTokenBalance: UFix64,
        _ unlockedTokenBalance: UFix64,
        _ claimableTokenAmount: UFix64
    ) {
        self.isJoined = isJoined
        self.lockedTokenBalance = lockedTokenBalance
        self.unlockedTokenBalance = unlockedTokenBalance
        self.claimableTokenAmount = claimableTokenAmount
    }
}
