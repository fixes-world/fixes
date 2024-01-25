// Fixes imports
// import "FRC20Indexer"
// import "FRC20FTShared"
// import "FRC20AccountsPool"
// import "FRC20Staking"
import "FRC20StakingManager"

transaction(
    stakeTick: String,
    rewardTick: String,
) {
    let controller: &FRC20StakingManager.StakingController

    prepare(acct: AuthAccount) {
        /** ------------- Start -- FRC20 Staking Controller General Initialization -------------  */
        // Initialize the FRC20 Staking Controller

        // Ensure Controller is initialized
        if acct.borrow<&AnyResource>(from: FRC20StakingManager.StakingControllerStoragePath) == nil {
            let ctrler <- FRC20StakingManager.createController()
            acct.save(<- ctrler, to: FRC20StakingManager.StakingControllerStoragePath)
        }
        /** ------------- End ---------------------------------------------------------- */

        self.controller = acct.borrow<&FRC20StakingManager.StakingController>(from: FRC20StakingManager.StakingControllerStoragePath)
            ?? panic("Could not borrow a reference to the FRC20 Staking Controller")
    }

    execute {
        self.controller.registerRewardStrategy(stakeTick: stakeTick, rewardTick: rewardTick)

        log("Reward Strategy Registered")
    }
}
