import "FRC20AccountsPool"
import "FRC20StakingManager"

transaction(
    tick: String,
    vestingBatchAmount: UInt32,
    vestingInterval: UFix64,
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
        self.controller.donateAllSharedPoolFlowTokenToVesting(
            tick: tick,
            childType: FRC20AccountsPool.ChildAccountType.Market,
            vestingBatchAmount: vestingBatchAmount,
            vestingInterval: vestingInterval
        )
    }
}
