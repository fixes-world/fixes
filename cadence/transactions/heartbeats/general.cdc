// Fixes imports
import "FixesHeartbeat"

transaction(
    scope: String
) {
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
        self.heartbeat.tick(scope: scope)
    }
}
