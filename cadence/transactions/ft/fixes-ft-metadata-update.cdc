import "FlowToken"
import "FungibleToken"
// Fixes Imports
import "FungibleTokenManager"
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"
import "FRC20AccountsPool"

transaction(
    symbol: String,
    logoUrl: String?,
    logoImageType: String?,
    displayName: String?,
    description: String?,
    externalUrl: String?,
    twitterUrl: String?,
    discordUrl: String?,
    telegramUrl: String?,
    githubUrl: String?,
) {
    let tickerName: String
    let managerRef: auth(FungibleTokenManager.Sudo) &FungibleTokenManager.Manager

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

        /** ------------- Prepare the Fungible Token Manager - Start ----------- */
        let managerPath = FungibleTokenManager.getManagerStoragePath()
        if acct.storage.borrow<&FungibleTokenManager.Manager>(from: managerPath) == nil {
            acct.storage.save(<- FungibleTokenManager.createManager(), to: managerPath)

            // create the public capability for the manager
            let managerPubPath = FungibleTokenManager.getManagerPublicPath()
            acct.capabilities.unpublish(managerPubPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FungibleTokenManager.Manager>(managerPath),
                at: managerPubPath
            )
        }

        self.managerRef = acct.storage.borrow<auth(FungibleTokenManager.Sudo) &FungibleTokenManager.Manager>(from: managerPath)
            ?? panic("Could not borrow a reference to the Fungible Token Manager")
        /** ------------- End -------------------------------------------------- */

        self.tickerName = "$".concat(symbol)
    }

    pre {
        FungibleTokenManager.isTokenSymbolEnabled(self.tickerName) == true: "Token is not enabled"
        logoImageType == nil || logoImageType == "svg" || logoImageType == "png" || logoImageType == "jpg" || logoImageType == "gif": "Invalid logo image type"
    }

    execute {
        let store = self.managerRef.borrowManagedFTStore(self.tickerName)
            ?? panic("Could not borrow a reference to the Fungible Token Store")

        let tokenSymbol = store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol) as! String?
            ?? panic("Symbol is not set")
        assert(symbol == tokenSymbol, message: "Symbol is not set correctly")

        // set logo url
        let logoKeyPrefix = store.getKeyByEnum(FRC20FTShared.ConfigType.FungibleTokenLogoPrefix)!

        if logoUrl != nil && logoImageType != nil {
            let logoStoreKey = logoKeyPrefix.concat(logoImageType!)
            store.set(logoStoreKey, value: logoUrl!)
        }
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
