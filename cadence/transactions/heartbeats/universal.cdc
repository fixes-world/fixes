// Fixes imports
import "FixesHeartbeat"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20StakingManager"

transaction() {
    let heartbeat: &FixesHeartbeat.Heartbeat

    prepare(acct: auth(Storage, Capabilities) &Account) {
        /** ------------- Start -- Fixes Heartbeat Initialization ------------  */
        // ensure resource
        if acct.storage.borrow<&AnyResource>(from: FixesHeartbeat.storagePath) == nil {
            acct.storage.save(<- FixesHeartbeat.createHeartbeat(), to: FixesHeartbeat.storagePath)
        }
        /** ------------- End ---------------------------------------------------------- */

        self.heartbeat = acct.storage.borrow<&FixesHeartbeat.Heartbeat>(from: FixesHeartbeat.storagePath)
            ?? panic("Could not borrow a reference to the heartbeat")
    }

    execute {
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        // Tick for staking
        let platformTickerName = FRC20FTShared.getPlatformStakingTickerName()
        if acctsPool.getFRC20StakingAddress(tick: platformTickerName) != nil {
            self.heartbeat.tick(scope: "Staking:".concat(platformTickerName))
        }
        // Tick for lottery
        self.heartbeat.tick(scope: "FGameLottery")
        // Tick for Votes
        self.heartbeat.tick(scope: "FRC20Votes")
        // Tick for TradablePool
        self.heartbeat.tick(scope: "TradablePool")
    }
}
