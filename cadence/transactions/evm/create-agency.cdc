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
    prepare(acct: auth(Storage, Capabilities) &Account) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.storage.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        // check if agency manager already exists
        assert(
            acct.storage.borrow<&AnyResource>(from: EVMAgent.evmAgencyManagerStoragePath) == nil,
            message: "Agency Manager already exists!"
        )

        // Get a reference to the signer's stored vault
        let vaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        assert(
            initialFundingAmt >= 1.0,
            message: "Initial funding amount must be at least 1.0"
        )

        /** ------------- Create the Inscription - Start ------------- */
        let insDataStr = FixesInscriptionFactory.buildAcctAgencyCreate()
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
        let newAccount = Account(payer: acct)
        let receiverRef = newAccount
            .capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            .borrow()
            ?? panic("Could not borrow receiver reference to the newly created account")
        receiverRef.deposit(from: <- vaultRef.withdraw(amount: initialFundingAmt))

        let cap = newAccount.capabilities
            .account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()
        /** ------------- End --------------------------------------- */
        // singleton resource
        let agencyCenter = EVMAgent.borrowAgencyCenter()

        // Create agency account
        let agencyMgr <- agencyCenter.createAgency(ins: insRef, cap)
        acct.storage.save(<- agencyMgr, to: EVMAgent.evmAgencyManagerStoragePath)
    }
}
