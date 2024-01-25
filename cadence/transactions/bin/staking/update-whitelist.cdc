// Fixes imports
// import "FRC20Indexer"
// import "FRC20FTShared"
// import "FRC20AccountsPool"
// import "FRC20Staking"
import "FRC20StakingManager"

transaction(
    addr: Address,
    value: Bool,
) {
    prepare(acct: AuthAccount) {
        let stakingAdmin = acct.borrow<&FRC20StakingManager.StakingAdmin>(from: FRC20StakingManager.StakingAdminStoragePath)
            ?? panic("Could not borrow a reference to the StakingAdmin")
        stakingAdmin.updateWhitelist(address: addr, isWhitelisted: value)
    }
}
