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
    let pool: &FRC20AccountsPool.Pool{FRC20AccountsPool.PoolPublic}
    let ins: &Fixes.Inscription
    let childAccountCap: Capability<&AuthAccount>
    let manager: &FRC20MarketManager.Manager

    prepare(acct: AuthAccount) {
        // ----------- Prepare the pool -----------

        self.pool = FRC20AccountsPool.borrowAccountsPool()

        // ----------- Prepare the inscription -----------

        // build the metadata string
        let dataStr = FixesInscriptionFactory.buildMarketEnable(tick: tick)

        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)

        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
			?? panic("Could not borrow reference to the owner's Vault!")
        let flowToReserve <- vaultRef.withdraw(amount: estimatedReqValue)

        // Create the Inscription first
        let newIns <- FixesInscriptionFactory.createFrc20Inscription(
            dataStr,
            <- (flowToReserve as! @FlowToken.Vault)
        )

        // save the new Inscription to storage
        let newInsId = newIns.getId()
        let newInsPath = Fixes.getFixesStoragePath(index: newInsId)
        assert(
            acct.borrow<&AnyResource>(from: newInsPath) == nil,
            message: "Inscription with ID ".concat(newInsId.toString()).concat(" already exists!")
        )
        acct.save(<- newIns, to: newInsPath)

        // borrow a reference to the new Inscription
        self.ins = acct.borrow<&Fixes.Inscription>(from: newInsPath)
            ?? panic("Could not borrow reference to the new Inscription!")

        // ---- create market account ----

        // create a new Account, no keys needed
        let newAccount = AuthAccount(payer: acct)

        // deposit 1.0 FLOW to the newly created account
        assert(initialFundingAmt >= 1.0, message: "initialFundingAmt must be >= 1.0")

        // Get a reference to the signer's stored vault
        let flowToNewAccount <- vaultRef.withdraw(amount: initialFundingAmt)

        let receiverRef = newAccount.getCapability(/public/flowTokenReceiver)
            .borrow<&{FungibleToken.Receiver}>()
            ?? panic("Could not borrow receiver reference to the newly created account")
        receiverRef.deposit(from: <- flowToNewAccount)

        /* --- Link the AuthAccount Capability --- */
        //
        self.childAccountCap = newAccount.linkAccount(HybridCustody.LinkedAccountPrivatePath)
            ?? panic("problem linking account Capability for new account")

        // ---- ensure the FRC20MarketManager exists in your account ----

        // if the FRC20MarketManager doesn't exist in storage, create it
        if acct.borrow<&FRC20MarketManager.Manager>(from: FRC20MarketManager.FRC20MarketManagerStoragePath) == nil {
            acct.save(<- FRC20MarketManager.createManager(), to: FRC20MarketManager.FRC20MarketManagerStoragePath)
        }
        self.manager = acct.borrow<&FRC20MarketManager.Manager>(from: FRC20MarketManager.FRC20MarketManagerStoragePath)
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

