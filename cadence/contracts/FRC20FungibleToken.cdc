/**

> Author: FIXeS World <https://fixes.world/>

# FRC20FungibleToken

This is the fungible token contract for all FRC20 tokens. It is the template contract that is used to deploy.

*/

import "FungibleToken"
import "ViewResolver"
import "MetadataViews"
import "FungibleTokenMetadataViews"
// Fixes imports
import "Fixes"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20AccountsPool"

/// This is the template source for a FRC20 Fungible Token
/// The contract is deployed in the child account of the FRC20Indexer
/// All real FRC20 tokens are deployed in the FRC20Indexer, and
/// the FT Token issued by the FRC20FTShared.Change
access(all) contract FRC20FungibleToken: FungibleToken, ViewResolver {

    /// Total supply of FRC20FungibleToken in existence
    /// This value is only a record of the quantity existing in the form of Flow Fungible Tokens.
    /// It does not represent the total quantity of the token that has been minted.
    /// The total quantity of the token that has been minted is loaded from the FRC20Indexer.
    access(all)
    var totalSupply: UFix64

    /// The event that is emitted when the contract is created
    access(all) event TokensInitialized(initialSupply: UFix64)

    /// The event that is emitted when tokens are withdrawn from a Vault
    access(all) event TokensWithdrawn(amount: UFix64, from: Address?)

    /// The event that is emitted when tokens are deposited to a Vault
    access(all) event TokensDeposited(amount: UFix64, to: Address?)

    /// The event that is emitted when new tokens are minted
    access(all) event TokensConvertedToStanard(amount: UFix64, by: Address)

    /// The event that is emitted when tokens are destroyed
    access(all) event TokensConvertedToFRC20(amount: UFix64, by: Address)

    /// The public interface for the FRC20 FT
    ///
    access(all) resource interface FRC20Metadata {
        /// Is the vault valid
        access(all) view
        fun isValidVault(): Bool
        /// Get the ticker name of the token
        access(all) view
        fun getTickerName(): String
        /// Get the change's from address
        access(all) view
        fun getSourceAddress(): Address
    }

    /// Each user stores an instance of only the Vault in their storage
    /// The functions in the Vault and governed by the pre and post conditions
    /// in FungibleToken when they are called.
    /// The checks happen at runtime whenever a function is called.
    ///
    /// Resources can only be created in the context of the contract that they
    /// are defined in, so there is no way for a malicious user to create Vaults
    /// out of thin air. A special Minter resource needs to be defined to mint
    /// new tokens.
    ///
    access(all) resource Vault: FRC20Metadata, FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance, MetadataViews.Resolver {
        /// The total balance of this vault
        access(all)
        var balance: UFix64
        // The change should be inside the vault
        access(self)
        var change: @FRC20FTShared.Change?

        /// Initialize the balance at resource creation time
        init(balance: UFix64) {
            pre {
                balance == 0.0: "For initialization, the balance must be zero"
            }
            // Initialize with a zero balance and nil change
            self.balance = balance
            self.change <- nil
        }

        /// @deprecated after Cadence 1.0
        destroy() {
            // You can not destroy a Change with a non-zero balance
            pre {
                self.balance == UFix64(0): "Balance must be zero for destroy"
            }
            destroy self.change
        }

        /// ----- Internal Methods -----

        /// Borrow the change reference
        ///
        access(contract)
        fun borrowChangeRef(): &FRC20FTShared.Change? {
            return &self.change as &FRC20FTShared.Change?
        }

        /// The initialize method for the Vault, a Vault for FRC20 must be initialized with a Change
        ///
        access(contract)
        fun initialize(_ change: @FRC20FTShared.Change) {
            pre {
                self.change == nil: "The change must be nil"
                change.isBackedByVault() == false: "The change must not be backed by a vault"
                change.isStakedTick() == false: "The change must not be staked"
                change.isTreasuryLPVoucher() == false: "The change must not be a treasury LP voucher"
                change.tick == FRC20FungibleToken.getSymbol(): "The change must be backed by the same ticker"
            }
            post {
                self.isValidVault(): "The vault must be valid"
            }
            let balance = change.getBalance()
            let from = change.from
            self.change <-! change
            // update balance
            self.syncBalance()
        }

        /// Extract the change from the vault
        ///
        access(contract)
        fun extract(): @FRC20FTShared.Change {
            pre {
                self.isValidVault(): "The vault must be valid"
            }
            post {
                self.change == nil: "The change must be nil"
            }
            let balance = self.change?.getBalance()!

            var retChange: @FRC20FTShared.Change? <- nil
            retChange <-> self.change
            // update balance
            self.syncBalance()

            // return the change
            return <- retChange!
        }

        /// The balance can be only updated by the change
        ///
        access(self)
        fun syncBalance() {
            if self.change == nil {
                self.balance = 0.0
            } else {
                self.balance = (self.change?.getBalance())!
            }
        }

        /// --------- Implement FRC20Metadata --------- ///

        /// Is the vault valid
        access(all) view
        fun isValidVault(): Bool {
            return self.change != nil
        }

        /// Get the ticker name of the token
        ///
        access(all) view
        fun getTickerName(): String {
            return self.change?.tick ?? panic("The change must be initialized")
        }

        /// Get the change's from address
        ///
        access(all) view
        fun getSourceAddress(): Address {
            return self.change?.from ?? panic("The change must be initialized")
        }

        /// --------- Implement FungibleToken.Provider --------- ///

        /// Function that takes an amount as an argument
        /// and withdraws that amount from the Vault.
        /// It creates a new temporary Vault that is used to hold
        /// the money that is being transferred. It returns the newly
        /// created Vault to the context that called so it can be deposited
        /// elsewhere.
        ///
        /// @param amount: The amount of tokens to be withdrawn from the vault
        /// @return The Vault resource containing the withdrawn funds
        ///
        access(all)
        fun withdraw(amount: UFix64): @FungibleToken.Vault {
            pre {
                self.isValidVault(): "The vault must be valid"
            }
            let changeRef = self.borrowChangeRef()!
            let newChange <- changeRef.withdrawAsChange(amount: amount)
            // update balance
            self.syncBalance()

            // initialize the new vault with the amount
            let newVault <- FRC20FungibleToken.createEmptyVault()
            newVault.initialize(<- newChange)

            // emit the event
            emit TokensWithdrawn(
                amount: amount,
                from: self.owner?.address
            )
            return <- newVault
        }

        /// --------- Implement FungibleToken.Receiver --------- ///

        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        /// @param from: The Vault resource containing the funds that will be deposited
        ///
        access(all)
        fun deposit(from: @FungibleToken.Vault) {
            pre {
                self.isValidVault(): "The vault must be valid"
            }
            // the interface ensured that the vault is of the same type
            // so we can safely cast it
            let vault <- from as! @FRC20FungibleToken.Vault
            let change <- vault.extract()

            // when change extracted, the balance is updated and vault is useless
            destroy vault
            let depositedBalance = change.getBalance()

            // borrow the change reference
            let changeRef = self.borrowChangeRef()!
            FRC20FTShared.depositToChange(
                receiver: changeRef,
                change: <- change
            )
            // update balance
            self.syncBalance()

            emit TokensDeposited(
                amount: depositedBalance,
                to: self.owner?.address
            )
        }

        /// --------- Implement MetadataViews.Resolver --------- ///

        /// The way of getting all the Metadata Views implemented by FRC20FungibleToken
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        access(all)
        fun getViews(): [Type] {
            let contractViews = FRC20FungibleToken.getViews()
            return contractViews
        }

        /// The way of getting a Metadata View out of the FRC20FungibleToken
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        access(all)
        fun resolveView(_ view: Type): AnyStruct? {
            return FRC20FungibleToken.resolveView(view)
        }
    }

    /// ------------ FRC20 <> FungibleToken Methods ------------

    /// Issue new Fungible Tokens from a FRC20 FT Change
    ///
    access(all)
    fun convertFromIndexer(ins: &Fixes.Inscription): @FRC20FungibleToken.Vault {
        pre {
            ins.isExtractable(): "The inscription must be extractable"
        }

        let frc20Indexer = FRC20Indexer.getIndexer()
        let meta = frc20Indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        // ensure tick is the same
        let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")
        assert(
            tick == FRC20FungibleToken.getSymbol(),
            message: "The token tick is not matched"
        )

        // ensure usage is 'convert'
        let usage = meta["usage"] ?? panic("The token usage is not found")
        assert(
            usage == "convert",
            message: "The token usage is not matched"
        )

        let insOwner = ins.owner?.address ?? panic("The owner of the inscription is not found")
        let beforeBalance = frc20Indexer.getBalance(tick: tick, addr: insOwner)

        // withdraw the change from indexer
        let change <- frc20Indexer.withdrawChange(ins: ins)

        let afterBalance = frc20Indexer.getBalance(tick: tick, addr: insOwner)
        // ensure the balance is matched
        assert(
            beforeBalance - afterBalance == change.getBalance(),
            message: "The balance is not matched"
        )

        let retVault <- self.createEmptyVault()
        retVault.initialize(<- change)

        // emit the event
        emit TokensConvertedToStanard(
            amount: retVault.balance,
            by: insOwner,
        )

        // update the total supply
        FRC20FungibleToken.totalSupply = FRC20FungibleToken.totalSupply + retVault.balance

        // return the new vault
        return <- retVault
    }

    /// Burn Fungible Tokens and convert into a FRC20 FT Change
    ///
    access(all)
    fun convertBackToIndexer(ins: &Fixes.Inscription, vault: @FungibleToken.Vault) {
        pre {
            ins.isExtractable(): "The inscription must be extractable"
            vault.isInstance(Type<@FRC20FungibleToken.Vault>()): "The vault must be of the same type as the token"
        }

        let frc20Indexer = FRC20Indexer.getIndexer()
        let meta = frc20Indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        // ensure tick is the same
        let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")
        assert(
            tick == FRC20FungibleToken.getSymbol(),
            message: "The token tick is not matched"
        )

        let fromVault <- vault as! @FRC20FungibleToken.Vault
        let retChange <- fromVault.extract()
        // no need to emit the event, it is emitted in the extract function
        destroy fromVault

        let convertBalance = retChange.getBalance()

        // before balance
        let insOwner = ins.owner?.address ?? panic("The owner of the inscription is not found")
        let beforeBalance = frc20Indexer.getBalance(tick: tick, addr: insOwner)

        frc20Indexer.depositChange(ins: ins, change: <- retChange)

        // after balance
        let afterBalance = frc20Indexer.getBalance(tick: tick, addr: insOwner)
        // ensure the balance is matched
        assert(
            afterBalance - beforeBalance == convertBalance,
            message: "The balance is not matched"
        )

        // emit the converted event
        emit TokensConvertedToFRC20(
            amount: convertBalance,
            by: insOwner,
        )

        // update the total supply
        FRC20FungibleToken.totalSupply = FRC20FungibleToken.totalSupply - convertBalance
    }

    /// ------------ General Functions ------------

    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context. A user must call this function
    /// and store the returned Vault in their storage in order to allow their
    /// account to be able to receive deposits of this token type.
    ///
    /// @return The new Vault resource
    ///
    access(all)
    fun createEmptyVault(): @Vault {
        return <-create Vault(balance: 0.0)
    }

    /// Borrow the shared store
    ///
    access(all)
    fun borrowSharedStore(): &FRC20FTShared.SharedStore{FRC20FTShared.SharedStorePublic} {
        let addr = self.account.address
        return FRC20FTShared.borrowStoreRef(addr) ?? panic("Config store not found")
    }

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    access(all)
    fun resolveView(_ view: Type): AnyStruct? {
        // external url
        let externalUrl = FRC20FungibleToken.getExternalUrl()
        switch view {
            case Type<MetadataViews.ExternalURL>():
                return externalUrl != nil
                    ? MetadataViews.ExternalURL(externalUrl!)
                    : MetadataViews.ExternalURL("https://fixes.world/")
            case Type<FungibleTokenMetadataViews.FTView>():
                return FungibleTokenMetadataViews.FTView(
                    ftDisplay: self.resolveView(Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                    ftVaultData: self.resolveView(Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                )
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let frc20Indexer = FRC20Indexer.getIndexer()
                let store = FRC20FungibleToken.borrowSharedStore()
                let tick = FRC20FungibleToken.getSymbol()

                if let display = frc20Indexer.getTokenDisplay(tick: tick) {
                    // medias
                    let medias: [MetadataViews.Media] = []
                    let logoKey = store.getKeyByEnum(FRC20FTShared.ConfigType.FungibleTokenLogoPrefix)!
                    if let iconUrl = store.get(logoKey) as! String? {
                        medias.append(MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: iconUrl),
                            mediaType: "image/png" // default is png
                        ))
                    }
                    if let iconUrl = store.get(logoKey.concat("png")) as! String? {
                        medias.append(MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: iconUrl),
                            mediaType: "image/png"
                        ))
                    }
                    if let iconUrl = store.get(logoKey.concat("svg")) as! String? {
                        medias.append(MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: iconUrl),
                            mediaType: "image/svg+xml"
                        ))
                    }
                    if let iconUrl = store.get(logoKey.concat("jpg")) as! String? {
                        medias.append(MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: iconUrl),
                            mediaType: "image/jpeg"
                        ))
                    }
                    // socials
                    let socialDict: {String: MetadataViews.ExternalURL} = {}
                    let socialKey = store.getKeyByEnum(FRC20FTShared.ConfigType.FungibleTokenSocialPrefix)!
                    // load social infos
                    if let socialUrl = store.get(socialKey.concat("twitter")) {
                        socialDict["twitter"] = MetadataViews.ExternalURL((socialUrl as! String?)!)
                    }
                    if let socialUrl = store.get(socialKey.concat("telegram")) {
                        socialDict["telegram"] = MetadataViews.ExternalURL((socialUrl as! String?)!)
                    }
                    if let socialUrl = store.get(socialKey.concat("discord")) {
                        socialDict["discord"] = MetadataViews.ExternalURL((socialUrl as! String?)!)
                    }
                    if let socialUrl = store.get(socialKey.concat("github")) {
                        socialDict["github"] = MetadataViews.ExternalURL((socialUrl as! String?)!)
                    }
                    if let socialUrl = store.get(socialKey.concat("website")) {
                        socialDict["website"] = MetadataViews.ExternalURL((socialUrl as! String?)!)
                    }
                    // override all customized fields
                    return FungibleTokenMetadataViews.FTDisplay(
                        name: FRC20FungibleToken.getDisplayName() ?? display.name,
                        symbol: tick,
                        description: FRC20FungibleToken.getTokenDescription() ?? display.description,
                        externalURL: externalUrl != nil
                            ? MetadataViews.ExternalURL(externalUrl!)
                            : display.externalURL,
                        logos: medias.length > 0
                            ? MetadataViews.Medias(medias)
                            : display.logos,
                        socials: socialDict
                    )
                }
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                let prefix = FRC20FungibleToken.getPathPrefix()
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: FRC20FungibleToken.getVaultStoragePath(),
                    receiverPath: FRC20FungibleToken.getReceiverPublicPath(),
                    metadataPath: FRC20FungibleToken.getVaultPublicPath(),
                    providerPath: PrivatePath(identifier: prefix.concat("Vault"))!,
                    receiverLinkedType: Type<&FRC20FungibleToken.Vault{FungibleToken.Receiver}>(),
                    metadataLinkedType: Type<&FRC20FungibleToken.Vault{FungibleToken.Balance, MetadataViews.Resolver}>(),
                    providerLinkedType: Type<&FRC20FungibleToken.Vault{FungibleToken.Provider}>(),
                    createEmptyVaultFunction: (fun (): @FRC20FungibleToken.Vault {
                        return <-FRC20FungibleToken.createEmptyVault()
                    })
                )
            // case Type<FungibleTokenMetadataViews.TotalSupply>():
            //     let indexer = FRC20Indexer.getIndexer()
            //     let tick = FRC20FungibleToken.getTickerName()
            //     if let tokenMeta = indexer.getTokenMeta(tick: tick) {
            //         return FungibleTokenMetadataViews.TotalSupply(
            //             totalSupply: tokenMeta.max
            //         )
            //     } else {
            //         return nil
            //     }
        }
        return nil
    }

    /// Function that returns all the Metadata Views implemented by a Fungible Token
    ///
    /// @return An array of Types defining the implemented views. This value will be used by
    ///         developers to know which parameter to pass to the resolveView() method.
    ///
    access(all)
    fun getViews(): [Type] {
        return [
            Type<MetadataViews.ExternalURL>(),
            Type<FungibleTokenMetadataViews.FTView>(),
            Type<FungibleTokenMetadataViews.FTDisplay>(),
            Type<FungibleTokenMetadataViews.FTVaultData>()
        ]
    }

    /// the real total supply is loaded from the FRC20Indexer
    ///
    access(all) view
    fun getTotalSupply(): UFix64 {
        let frc20Indexer = FRC20Indexer.getIndexer()
        let tokenMeta = frc20Indexer.getTokenMeta(tick: self.getSymbol())!
        return tokenMeta.max
    }

    /// Get the total supply of the standard fungible token
    ///
    access(all) view
    fun getStandardFungibleTokenTotalSupply(): UFix64 {
        return self.totalSupply
    }

    /// Get the ticker name of the token
    ///
    access(all) view
    fun getSymbol(): String {
        let store = self.borrowSharedStore()
        let tick = store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol) as! String?
        return tick ?? panic("Ticker name not found")
    }

    /// Get the display name of the token
    ///
    access(all) view
    fun getDisplayName(): String? {
        let store = self.borrowSharedStore()
        return store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenDisplayName) as! String?
    }

    /// Get the token description
    ///
    access(all) view
    fun getTokenDescription(): String? {
        let store = self.borrowSharedStore()
        return store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenDescription) as! String?
    }

    /// Get the external URL of the token
    ///
    access(all) view
    fun getExternalUrl(): String? {
        let store = self.borrowSharedStore()
        return store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenExternalUrl) as! String?
    }

    /// Get the icon URL of the token
    ///
    access(all) view
    fun getLogoUrl(): String? {
        let store = self.borrowSharedStore()
        let key = store.getKeyByEnum(FRC20FTShared.ConfigType.FungibleTokenLogoPrefix)!
        let iconDefault = store.get(key) as! String?
        let iconPng = store.get(key.concat("png")) as! String?
        let iconSvg = store.get(key.concat("svg")) as! String?
        let iconJpg = store.get(key.concat("jpg")) as! String?
        return iconPng ?? iconSvg ?? iconJpg ?? iconDefault
    }

    /// Get the prefix for the storage paths
    ///
    access(all) view
    fun getPathPrefix(): String {
        return "FRC20FT_".concat(self.account.address.toString()).concat(self.getSymbol()).concat("_")
    }

    /// Get the storage path for the Vault
    ///
    access(all) view
    fun getVaultStoragePath(): StoragePath {
        let prefix = FRC20FungibleToken.getPathPrefix()
        return StoragePath(identifier: prefix.concat("Vault"))!
    }

    /// Get the public path for the Vault
    ///
    access(all) view
    fun getVaultPublicPath(): PublicPath {
        let prefix = FRC20FungibleToken.getPathPrefix()
        return PublicPath(identifier: prefix.concat("Metadata"))!
    }

    /// Get the public path for the Receiver
    ///
    access(all) view
    fun getReceiverPublicPath(): PublicPath {
        let prefix = FRC20FungibleToken.getPathPrefix()
        return PublicPath(identifier: prefix.concat("Receiver"))!
    }

    /// Initialize the contract with ticker name
    ///
    init() {
        // Initialize the total supply to zero
        self.totalSupply = 0.0

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)

        // Singleton resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        let isSysmtemDeploy = self.account.address == frc20Indexer.owner?.address
        if isSysmtemDeploy {
            // DO NOTHING, It will be a template contract for deploying new FRC20 Fungible tokens
            return
        }

        // Step.0 Ensure shared store exists

        // Initialize the shared store
        if self.account.borrow<&AnyResource>(from: FRC20FTShared.SharedStoreStoragePath) == nil {
            let sharedStore <- FRC20FTShared.createSharedStore()
            self.account.save(<- sharedStore, to: FRC20FTShared.SharedStoreStoragePath)
        }
        // link the resource to the public path
        // @deprecated after Cadence 1.0
        if self.account
            .getCapability<&FRC20FTShared.SharedStore{FRC20FTShared.SharedStorePublic}>(FRC20FTShared.SharedStorePublicPath)
            .borrow() == nil {
            self.account.unlink(FRC20FTShared.SharedStorePublicPath)
            self.account.link<&FRC20FTShared.SharedStore{FRC20FTShared.SharedStorePublic}>(FRC20FTShared.SharedStorePublicPath, target: FRC20FTShared.SharedStoreStoragePath)
        }
        // borrow the shared store
        let store = self.borrowSharedStore()

        // Step.1 Try get the ticker name from the shared store
        var tickerName = store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol) as! String?
        if tickerName == nil {
            // try load the ticker name from AccountPools
            let addrDict = acctsPool.getFRC20Addresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
            let contractAddr = self.account.address
            addrDict.forEachKey(fun (key: String): Bool {
                if let addr = addrDict[key] {
                    if addr == contractAddr {
                        tickerName = key
                        return false
                    }
                }
                return true
            })

            // set the ticker name
            if tickerName != nil {
                store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol, value: tickerName!)
            }
        }

        // ensure frc20 metadata exists
        assert(
            tickerName != nil && frc20Indexer.getTokenMeta(tick: tickerName!) != nil,
            message: "The FRC20 token does not exist"
        )

        // Step.2 Setup the vault and receiver for the contract account

        let storagePath = self.getVaultStoragePath()
        let publicPath = self.getVaultPublicPath()
        let receiverPath = self.getReceiverPublicPath()

        // Create the Vault with the total supply of tokens and save it in storage.
        let vault <- create Vault(balance: self.totalSupply)
        self.account.save(<-vault, to: storagePath)

        // @deprecated after Cadence 1.0
        // Create a public capability to the stored Vault that exposes
        // the `deposit` method through the `Receiver` interface.
        self.account.link<&{FungibleToken.Receiver}>(receiverPath, target: storagePath)
        // Create a public capability to the stored Vault that only exposes
        // the `balance` field and the `resolveView` method through the `Balance` interface
        self.account.link<&FRC20FungibleToken.Vault{FungibleToken.Balance}>(publicPath, target: storagePath)
    }
}
