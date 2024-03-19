// Fixes imports
import "FixesHeartbeat"

transaction(
    scope: String
) {
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
        self.heartbeat.tick(scope: scope)
    }
}
