// Fixes imports
import "FixesHeartbeat"
import "FRC20AccountsPool"
import "FRC20StakingManager"

transaction() {
    let heartbeat: &FixesHeartbeat.Heartbeat

    prepare(acct: AuthAccount) {
        /** ------------- Start -- Fixes Heartbeat Initialization ------------  */
        // ensure resource
        if acct.borrow<&AnyResource>(from: FixesHeartbeat.storagePath) == nil {
            acct.save(<- FixesHeartbeat.create(), to: FixesHeartbeat.storagePath)
        }
        /** ------------- End ---------------------------------------------------------- */

        self.heartbeat = acct.borrow<&FixesHeartbeat.Heartbeat>(from: FixesHeartbeat.storagePath)
            ?? panic("Could not borrow a reference to the heartbeat")
    }

    execute {
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        // Tick for staking
        let platformTickerName = FRC20StakingManager.getPlatformStakingTickerName()
        if acctsPool.getFRC20StakingAddress(tick: platformTickerName) != nil {
            self.heartbeat.tick(scope: "Staking:".concat(platformTickerName))
        }
        // Tick for lottery
        self.heartbeat.tick(scope: "FGameLottery")
        // Tick for Votes
        self.heartbeat.tick(scope: "FRC20Votes")
    }
}
