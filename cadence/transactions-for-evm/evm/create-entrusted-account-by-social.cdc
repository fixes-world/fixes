#allowAccountLinking
import "FungibleToken"
import "FlowToken"
import "HybridCustody"
// Import the Fixes contract
import "EVMAgent"

transaction(
    platform: String,
    platformId: String,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        // Get a reference to the signer's stored vault
        let vaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        // Pick a random agency
        let agencyCenter = EVMAgent.borrowAgencyCenter()
        let agency = agencyCenter.pickValidAgency()
            ?? panic("No valid agency found")

        /** ------------- Create new Account - Start ------------- */
        // create new account
        let newAccount = Account(payer: acct)
        let cap = newAccount.capabilities
            .account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()
        /** ------------- End --------------------------------------- */

        let refundCreationFee <- agency.createSocialEntrustedAccount(
            platform: platform,
            platformId: platformId,
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
