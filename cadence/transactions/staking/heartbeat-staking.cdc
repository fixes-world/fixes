// Fixes imports
import "FixesHeartbeat"
import "FRC20AccountsPool"

transaction(
    tick: String
) {
    let heartbeat: &FixesHeartbeat.Heartbeat

    prepare(acct: AuthAccount) {

        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        assert(
            acctsPool.getFRC20StakingAddress(tick: tick) != nil,
            message: "FRC20 staking address not found"
        )

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
        self.heartbeat.tick(scope: "Staking:".concat(tick))
    }
}
