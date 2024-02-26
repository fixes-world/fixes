import "FlowToken"
import "FungibleToken"
// Import the Fixes contract
import "EVMAgent"

transaction(
    amt: UFix64
) {
    let manager: &EVMAgent.AgencyManager
    let receiver: &FlowToken.Vault{FungibleToken.Receiver}

    prepare(acct: AuthAccount) {
        // Borrow the manager
        self.manager = acct.borrow<&EVMAgent.AgencyManager>(from: EVMAgent.evmAgencyManagerStoragePath)
            ?? panic("Could not borrow the manager")

        self.receiver = acct
            .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            .borrow() ?? panic("Could not borrow receiver capability")
    }

    execute {
        self.receiver.deposit(from: <- self.manager.withdraw(amt: amt))
        log("Deposited into account")
    }
}
