#allowAccountLinking
// Thirdparty imports
import "FungibleToken"
import "FlowToken"
import "HybridCustody"
// Fixes imports
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20AccountsPool"
import "FRC20MarketManager"

transaction(
    tick: String,
    initialFundingAmt: UFix64,
    properties: {UInt8: String}
) {
    let pool: &{FRC20AccountsPool.PoolPublic}
    let ins: auth(Fixes.Extractable) &Fixes.Inscription
    let childAccountCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>
    let manager: auth(FRC20MarketManager.Manage) &FRC20MarketManager.Manager

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

        // ----------- Prepare the pool -----------

        self.pool = FRC20AccountsPool.borrowAccountsPool()

        // ----------- Prepare the inscription -----------

        // build the metadata string
        let dataStr = FixesInscriptionFactory.buildMarketEnable(tick: tick)

        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)

        // Get a reference to the signer's stored vault
        let vaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
			?? panic("Could not borrow reference to the owner's Vault!")
        let flowToReserve <- vaultRef.withdraw(amount: estimatedReqValue)

        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            dataStr,
            <- (flowToReserve as! @FlowToken.Vault),
            store
        )

        // borrow a reference to the new Inscription
        self.ins = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow reference to the new Inscription!")

        // ---- create market account ----

        // create a new Account, no keys needed
        let newAccount = Account(payer: acct)

        // deposit 1.0 FLOW to the newly created account
        assert(initialFundingAmt >= 1.0, message: "initialFundingAmt must be >= 1.0")

        // Get a reference to the signer's stored vault
        let flowToNewAccount <- vaultRef.withdraw(amount: initialFundingAmt)

        let receiverRef = newAccount.capabilities
            .get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            .borrow()
            ?? panic("Could not borrow receiver reference to the newly created account")
        receiverRef.deposit(from: <- flowToNewAccount)

        /* --- Link the AuthAccount Capability --- */
        //
        self.childAccountCap = newAccount.capabilities
            .account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()

        // ---- ensure the FRC20MarketManager exists in your account ----

        // if the FRC20MarketManager doesn't exist in storage, create it
        if acct.storage.borrow<&FRC20MarketManager.Manager>(from: FRC20MarketManager.FRC20MarketManagerStoragePath) == nil {
            acct.storage.save(<- FRC20MarketManager.createManager(), to: FRC20MarketManager.FRC20MarketManagerStoragePath)
        }
        self.manager = acct.storage
            .borrow<auth(FRC20MarketManager.Manage) &FRC20MarketManager.Manager>(from: FRC20MarketManager.FRC20MarketManagerStoragePath)
            ?? panic("Could not borrow reference to the FRC20MarketManager")
    }

    pre {
        self.pool.getFRC20MarketAddress(tick: tick) == nil: "FRC20Market already exists for tick ".concat(tick)
    }

    execute {
        // add the newly created account to the pool
        FRC20MarketManager.enableAndCreateFRC20Market(
            ins: self.ins,
            newAccount: self.childAccountCap,
        )

        // set the properties
        let initProps: {FRC20FTShared.ConfigType: String} = {}
        for key in properties.keys {
            if let configType = FRC20FTShared.ConfigType(rawValue: key) {
                initProps[configType] = properties[key]!
            }
        }
        if initProps.keys.length > 0 {
            self.manager.updateMarketplaceProperties(tick: tick, initProps)
        }
        log("Done: Enable Market")
    }

    post {
        self.pool.getFRC20MarketAddress(tick: tick) != nil: "FRC20Market does not exist for tick ".concat(tick)
    }
}

