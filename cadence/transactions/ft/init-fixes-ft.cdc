#allowAccountLinking

import "FlowToken"
import "FungibleToken"
import "HybridCustody"
// Fixes Imports
import "FungibleTokenManager"
import "Fixes"
import "FixesInscriptionFactory"
import "FixesTradablePool"
import "FRC20FTShared"
import "FRC20AccountsPool"

transaction(
    symbol: String,
    maxSupply: UFix64,
    logoUrl: String,
    logoImageType: String,
    displayName: String?,
    description: String?,
    externalUrl: String?,
    twitterUrl: String?,
    discordUrl: String?,
    telegramUrl: String?,
    githubUrl: String?,
    isCreateTradablePool: Bool,
    tradablePoolSupply: UFix64,
    creatorFeePercentage: UFix64,
    feeMintAmount: UFix64,
) {
    let tickerName: String
    let newAcctCap: Capability<&AuthAccount>
    let initFtIns: &Fixes.Inscription
    let setupTradablePoolIns: &Fixes.Inscription?

    prepare(acct: AuthAccount) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        // Get a reference to the signer's stored vault
        let flowVaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        /** ------------- Create new Account - Start ------------- */
        let initialFundingAmt = 0.01
        // create new account
        let newAccount = AuthAccount(payer: acct)
        let receiverRef = newAccount.getCapability(/public/flowTokenReceiver)
            .borrow<&{FungibleToken.Receiver}>()
            ?? panic("Could not borrow receiver reference to the newly created account")
        receiverRef.deposit(from: <- flowVaultRef.withdraw(amount: initialFundingAmt))

        self.newAcctCap = newAccount.linkAccount(HybridCustody.LinkedAccountPrivatePath)
            ?? panic("problem linking account Capability for new account")
        /** ------------- End --------------------------------------- */

        self.tickerName = "$".concat(symbol)

        /** ------------- Create the Inscription - Start ------------- */
        let insDataStr = FixesInscriptionFactory.buildPureExecuting(tick: self.tickerName, usage: "init-ft", {})
        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(insDataStr)
        // get reserved cost
        let flowToReserve <- (flowVaultRef.withdraw(amount: estimatedReqValue) as! @FlowToken.Vault)
        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            insDataStr,
            <- flowToReserve,
            store
        )
        // borrow a reference to the new Inscription
        self.initFtIns = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow a reference to the newly created Inscription!")
        /** ------------- End --------------------------------------- */

        /** ------------- Create the Inscription 2 - Start ------------- */
        if isCreateTradablePool {
            let fields: {String: String} = {}
            if tradablePoolSupply > 0.0 {
                fields["supply"] = tradablePoolSupply.toString()
            }
            if creatorFeePercentage > 0.0 {
                fields["feePerc"] = creatorFeePercentage.toString()
            }
            if feeMintAmount > 0.0 {
                fields["freeAmount"] = feeMintAmount.toString()
            }
            let tradablePoolInsDataStr = FixesInscriptionFactory.buildPureExecuting(
                tick: self.tickerName,
                usage: "setup-tradable-pool",
                fields
            )
            // estimate the required storage
            let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(tradablePoolInsDataStr)
            // get reserved cost
            let flowToReserve <- (flowVaultRef.withdraw(amount: estimatedReqValue) as! @FlowToken.Vault)
            // Create the Inscription first
            let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
                tradablePoolInsDataStr,
                <- flowToReserve,
                store
            )
            // borrow a reference to the new Inscription
            self.setupTradablePoolIns = store.borrowInscriptionWritableRef(newInsId)
                ?? panic("Could not borrow a reference to the newly created Inscription!")
        } else {
            self.setupTradablePoolIns = nil
        }
        /** ------------- End --------------------------------------- */
    }

    pre {
        FungibleTokenManager.isTokenSymbolEnabled(self.tickerName) == false: "Token is already enabled"
        logoImageType == "svg" || logoImageType == "png" || logoImageType == "jpg" || logoImageType == "gif": "Invalid logo image type"
        !isCreateTradablePool || self.setupTradablePoolIns != nil: "Invalid Tradable Pool Inscription"
    }

    post {
        FungibleTokenManager.isTokenSymbolEnabled(self.tickerName) == true: "Token is not enabled"
    }

    execute {
        // Step.1 initialize Fungible Token
        FungibleTokenManager.initializeFixesFungibleTokenAccount(
            self.initFtIns,
            newAccount: self.newAcctCap
        )

        // Step.2 update token metadata
        let ftContractAddr = FungibleTokenManager.getFTContractAddress(self.tickerName)
            ?? panic("Could not get the Fungible Token contract address")

        let store = FRC20FTShared.borrowStoreRef(ftContractAddr)
            ?? panic("The shared store was not created")

        let tokenSymbol = store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol) as! String?
            ?? panic("Symbol is not set")
        assert(symbol == tokenSymbol, message: "Symbol is not set correctly")
        // set max supply
        store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenMaxSupply, value: maxSupply)
        // set logo url
        let logoKeyPrefix = store.getKeyByEnum(FRC20FTShared.ConfigType.FungibleTokenLogoPrefix)!
        let logoStoreKey = logoKeyPrefix.concat(logoImageType)
        store.set(logoStoreKey, value: logoUrl)
        // set display name
        if displayName != nil {
            store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenDisplayName, value: displayName)
        }
        // set description
        if description != nil {
            store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenDescription, value: description)
        }
        // set external url
        if externalUrl != nil {
            store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenExternalUrl, value: externalUrl)
        }
        // set socials
        let socialKey = store.getKeyByEnum(FRC20FTShared.ConfigType.FungibleTokenSocialPrefix)!
        if twitterUrl != nil {
            store.set(socialKey.concat("twitter"), value: twitterUrl)
        }
        if discordUrl != nil {
            store.set(socialKey.concat("discord"), value: discordUrl)
        }
        if telegramUrl != nil {
            store.set(socialKey.concat("telegram"), value: telegramUrl)
        }
        if githubUrl != nil {
            store.set(socialKey.concat("github"), value: githubUrl)
        }

        // Step.3 Setup Tradable Pool
        if isCreateTradablePool && self.setupTradablePoolIns != nil {
            FungibleTokenManager.setupTradablePoolResources(self.setupTradablePoolIns!)
        }
    }
}
