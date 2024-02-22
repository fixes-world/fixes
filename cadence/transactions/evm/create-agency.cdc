#allowAccountLinking
import "FlowToken"
import "FungibleToken"
import "HybridCustody"
// Import the Fixes contract
import "Fixes"
import "FixesInscriptionFactory"
import "EVMAgent"

transaction(
    initialFundingAmt: UFix64,
) {
    prepare(acct: AuthAccount) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        // check if agency manager already exists
        assert(
            acct.borrow<&EVMAgent.AgencyManager>(from: EVMAgent.evmAgencyManagerStoragePath) == nil,
            message: "Agency Manager already exists!"
        )

        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        assert(
            initialFundingAmt >= 1.0,
            message: "Initial funding amount must be at least 1.0"
        )

        /** ------------- Create the Inscription - Start ------------- */
        let insDataStr = FixesInscriptionFactory.buildEvmAgencyCreate(tick: "flows")
        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(insDataStr)
        // get reserved cost
        let flowToReserve <- (vaultRef.withdraw(amount: estimatedReqValue) as! @FlowToken.Vault)
        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            insDataStr,
            <- flowToReserve,
            store
        )
        // borrow a reference to the new Inscription
        let insRef = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow a reference to the newly created Inscription!")
        /** ------------- End --------------------------------------- */

        /** ------------- Create new Account - Start ------------- */
        // create new account
        let newAccount = AuthAccount(payer: acct)
        let receiverRef = newAccount.getCapability(/public/flowTokenReceiver)
            .borrow<&{FungibleToken.Receiver}>()
            ?? panic("Could not borrow receiver reference to the newly created account")
        receiverRef.deposit(from: <- vaultRef.withdraw(amount: initialFundingAmt))

        let cap = newAccount.linkAccount(HybridCustody.LinkedAccountPrivatePath)
            ?? panic("problem linking account Capability for new account")
        /** ------------- End --------------------------------------- */
        // singleton resource
        let agencyCenter = EVMAgent.borrowAgencyCenter()

        // Create agency account
        let agencyMgr <- agencyCenter.createAgency(ins: insRef, cap)
        acct.save(<- agencyMgr, to: EVMAgent.evmAgencyManagerStoragePath)

        // Refund the balance in the inscription
        let rufund <- insRef.extract()
        vaultRef.deposit(from: <- rufund)
    }
}
