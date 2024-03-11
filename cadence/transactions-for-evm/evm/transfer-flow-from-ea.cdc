import "FungibleToken"
import "FlowToken"
// Import the Fixes contract
import "EVMAgent"

transaction(
    to: Address,
    amt: UFix64,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    let sender: &FlowToken.Vault{FungibleToken.Provider}
    let recipient: &AnyResource{FungibleToken.Receiver}

    prepare(acct: AuthAccount) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "transfer-flow-from-ea(Address|UFix64)",
            params: [to.toString(), amt.toString()],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */

        self.sender = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) as &FlowToken.Vault{FungibleToken.Provider}?
            ?? panic("Could not borrow a reference to the sender's vault!")

        self.recipient = getAccount(to).getCapability(/public/flowTokenReceiver)
                .borrow<&AnyResource{FungibleToken.Receiver}>()
                ?? panic("Could not borrow receiver reference to the recipient's Vault")
    }

    execute {
        self.recipient.deposit(from: <- self.sender.withdraw(amount: amt))
    }
}
