#allowAccountLinking
import "FlowToken"
import "FungibleToken"
import "HybridCustody"
// Import the Fixes contract
import "Fixes"
import "FixesInscriptionFactory"
import "EVMAgent"

transaction(
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    prepare(acct: AuthAccount) {
        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        // Pick a random agency
        let agencyCenter = EVMAgent.borrowAgencyCenter()
        let agency = agencyCenter.pickValidAgency()
            ?? panic("No valid agency found")

        /** ------------- Create new Account - Start ------------- */
        // create new account
        let newAccount = AuthAccount(payer: acct)
        let cap = newAccount.linkAccount(HybridCustody.LinkedAccountPrivatePath)
            ?? panic("problem linking account Capability for new account")
        /** ------------- End --------------------------------------- */

        let refundCreationFee <- agency.createEntrustedAccount(
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp,
            cap
        )

        vaultRef.deposit(from: <- refundCreationFee)
    }

    execute {
        log("Account created successfully")
    }
}
