#allowAccountLinking

import "FlowToken"
import "FungibleToken"
import "HybridCustody"
// Fixes Imports
import "FungibleTokenManager"
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"

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
) {
    let tickerName: String
    let newAcctRef: &AuthAccount
    let newAcctCap: Capability<&AuthAccount>
    let initFtIns: &Fixes.Inscription

    prepare(acct: AuthAccount) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        /** ------------- Prepare the Fungible Token Manager - Start ----------- */
        let managerPath = FungibleTokenManager.getManagerStoragePath()
        if acct.borrow<&FungibleTokenManager.Manager>(from: managerPath) == nil {
            acct.save(<- FungibleTokenManager.createManager(), to: managerPath)

            // create the public capability for the manager
            let managerPubPath = FungibleTokenManager.getManagerPublicPath()
            acct.unlink(managerPubPath)
            acct.link<&FungibleTokenManager.Manager{FungibleTokenManager.ManagerPublic}>(
                managerPubPath,
                target: managerPath
            )
        }
        /** ------------- End -------------------------------------------------- */

        // Get a reference to the signer's stored vault
        let flowVaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        /** ------------- Create new Account - Start ------------- */
        let initialFundingAmt = 0.5
        // create new account
        let newAccount = AuthAccount(payer: acct)
        let receiverRef = newAccount.getCapability(/public/flowTokenReceiver)
            .borrow<&{FungibleToken.Receiver}>()
            ?? panic("Could not borrow receiver reference to the newly created account")
        receiverRef.deposit(from: <- flowVaultRef.withdraw(amount: initialFundingAmt))

        self.newAcctRef = &newAccount as &AuthAccount
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
    }

    pre {
        FungibleTokenManager.isTokenSymbolEnabled(self.tickerName) == false: "Token is already enabled"
        logoImageType == "svg" || logoImageType == "png" || logoImageType == "jpg" || logoImageType == "gif": "Invalid logo image type"
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
        assert(
            FungibleTokenManager.getFTContractAddress(self.tickerName) != nil,
            message: "Fungible Token contract address is not set"
        )

        let store = self.newAcctRef.borrow<&FRC20FTShared.SharedStore>(
            from: FRC20FTShared.SharedStoreStoragePath
        ) ?? panic("The shared store was not created")

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
            store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenDisplayName, value: displayName!)
        }
        // set description
        if description != nil {
            store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenDescription, value: description!)
        }
        // set external url
        if externalUrl != nil {
            store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenExternalUrl, value: externalUrl!)
        }
        // set socials
        let socialKey = store.getKeyByEnum(FRC20FTShared.ConfigType.FungibleTokenSocialPrefix)!
        if twitterUrl != nil {
            store.set(socialKey.concat("twitter"), value: twitterUrl!)
        }
        if discordUrl != nil {
            store.set(socialKey.concat("discord"), value: discordUrl!)
        }
        if telegramUrl != nil {
            store.set(socialKey.concat("telegram"), value: telegramUrl!)
        }
        if githubUrl != nil {
            store.set(socialKey.concat("github"), value: githubUrl!)
        }
    }
}
