import "FungibleToken"
import "MetadataViews"
import "FungibleTokenMetadataViews"
// Fixes imports
import "FRC20FTShared"
import "FRC20Indexer"

/// This is the template source for a FRC20 Fungible Token
/// When a new FRC20 FT contract is created, the deployer will replace
/// all instances of the string "FRC20FungibleToken" with the name of the
/// "FRC20TokenTICKER_NAME" contract and then replace all instances of the string
/// "TICKER_NAME" with the ticker name of the token.
pub contract FRC20FungibleToken: FungibleToken {

    /// Total supply of FRC20FungibleToken in existence
    /// This value is only a record of the quantity existing in the form of Flow Fungible Tokens.
    /// It does not represent the total quantity of the token that has been minted.
    /// The total quantity of the token that has been minted is loaded from the FRC20Indexer.
    pub var totalSupply: UFix64

    /// Storage and Public Paths
    pub let VaultStoragePath: StoragePath
    pub let VaultPublicPath: PublicPath
    pub let ReceiverPublicPath: PublicPath

    /// The event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    /// The event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    /// The event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    /// The event that is emitted when new tokens are minted
    pub event TokensConvertedToStanard(amount: UFix64)

    /// The event that is emitted when tokens are destroyed
    pub event TokensConvertedToFRC20(amount: UFix64)

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
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance, MetadataViews.Resolver {
        /// The total balance of this vault
        access(all)
        var balance: UFix64

        /// Initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
        }

        destroy() {
            // You can not destroy a Change with a non-zero balance
            pre {
                self.balance == UFix64(0): "Balance must be zero for destroy"
            }
        }

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
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        /// @param from: The Vault resource containing the funds that will be deposited
        ///
        pub fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @FRC20FungibleToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        /// This function only can be called by in the context of the contract before
        /// destruction.
        ///
        access(contract)
        fun extract(): UFix64 {
            let amount = self.balance
            self.balance = 0.0
            return amount
        }

        /// The way of getting all the Metadata Views implemented by FRC20FungibleToken
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        pub fun getViews(): [Type] {
            return [
                Type<FungibleTokenMetadataViews.FTView>(),
                Type<FungibleTokenMetadataViews.FTDisplay>(),
                Type<FungibleTokenMetadataViews.FTVaultData>(),
                Type<FungibleTokenMetadataViews.TotalSupply>()
            ]
        }

        /// The way of getting a Metadata View out of the FRC20FungibleToken
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<FungibleTokenMetadataViews.FTView>():
                    return FungibleTokenMetadataViews.FTView(
                        ftDisplay: self.resolveView(Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                        ftVaultData: self.resolveView(Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                    )
                case Type<FungibleTokenMetadataViews.FTDisplay>():
                    let tick = FRC20FungibleToken.getTickerName()
                    let indexer = FRC20Indexer.getIndexer()
                    return indexer.getTokenDisplay(tick: tick)
                case Type<FungibleTokenMetadataViews.FTVaultData>():
                    let prefix = FRC20FungibleToken.getPathPrefix()
                    return FungibleTokenMetadataViews.FTVaultData(
                        storagePath: FRC20FungibleToken.VaultStoragePath,
                        receiverPath: FRC20FungibleToken.ReceiverPublicPath,
                        metadataPath: FRC20FungibleToken.VaultPublicPath,
                        providerPath: PrivatePath(identifier: prefix.concat("Vault"))!,
                        receiverLinkedType: Type<&FRC20FungibleToken.Vault{FungibleToken.Receiver}>(),
                        metadataLinkedType: Type<&FRC20FungibleToken.Vault{FungibleToken.Balance, MetadataViews.Resolver}>(),
                        providerLinkedType: Type<&FRC20FungibleToken.Vault{FungibleToken.Provider}>(),
                        createEmptyVaultFunction: (fun (): @FRC20FungibleToken.Vault {
                            return <-FRC20FungibleToken.createEmptyVault()
                        })
                    )
                case Type<FungibleTokenMetadataViews.TotalSupply>():
                    let indexer = FRC20Indexer.getIndexer()
                    let tick = FRC20FungibleToken.getTickerName()
                    if let tokenMeta = indexer.getTokenMeta(tick: tick) {
                        return FungibleTokenMetadataViews.TotalSupply(
                            totalSupply: tokenMeta.max
                        )
                    } else {
                        return nil
                    }
            }
            return nil
        }
    }

    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context. A user must call this function
    /// and store the returned Vault in their storage in order to allow their
    /// account to be able to receive deposits of this token type.
    ///
    /// @return The new Vault resource
    ///
    pub fun createEmptyVault(): @Vault {
        return <-create Vault(balance: 0.0)
    }

    access(all)
    fun getTickerName(): String {
        // This string will be replaced by the real ticker name
        return "TICKER_NAME"
    }

    /// Withdraw all Fungible Tokens from a FRC20 FT Change
    ///
    access(all)
    fun withdrawFromChange(change: @FRC20FTShared.Change): @FRC20FungibleToken.Vault {
        pre {
            change.isBackedByVault(): "The change must be backed by a vault"
            change.tick == self.getTickerName(): "The change must be backed by the same ticker"
            change.getVaultType() == Type<@FRC20FungibleToken.Vault>(): "The change must be backed by the same type of vault"
        }
        let amount = change.getBalance()
        assert(
            amount > 0.0,
            message: "The change must be greater than zero."
        )
        let vault <- change.withdrawAsVault(amount: amount)
        assert(
            change.getBalance() == 0.0,
            message: "The change must be empty after the withdrawal."
        )
        destroy change
        // no need to emit the event, it is emitted in the withdraw function
        // no need to update the total supply, it is not changed
        return <- (vault as! @FRC20FungibleToken.Vault)
    }

    /// Issue new Fungible Tokens from a FRC20 FT Change
    ///
    access(account)
    fun mintByChange(change: @FRC20FTShared.Change): @FRC20FungibleToken.Vault {
        pre {
            change.isBackedByVault() == false: "The change must not be backed by a vault"
            change.tick == self.getTickerName(): "The change must be backed by the same ticker"
        }
        let extractedAmount = change.extract()
        assert(
            extractedAmount > 0.0,
            message: "The change must contain at least one token"
        )
        // destroy the empty change
        destroy change
        // update the total supply
        FRC20FungibleToken.totalSupply = FRC20FungibleToken.totalSupply + extractedAmount
        // emit the event
        emit TokensConvertedToStanard(amount: extractedAmount)
        // return the new vault
        return <-create Vault(balance: extractedAmount)
    }

    /// Burn Fungible Tokens and convert into a FRC20 FT Change
    ///
    access(account)
    fun burnIntoChange(vault: @FungibleToken.Vault, from: Address): @FRC20FTShared.Change {
        pre {
            vault.getType() == Type<@FRC20FungibleToken.Vault>(): "The vault must be of the same type as the token"
        }
        let fromVault <- vault as! @FRC20FungibleToken.Vault
        let amount = fromVault.extract()
        // the total supply is updated in the vault's destroy method
        destroy fromVault
        // update the total supply
        FRC20FungibleToken.totalSupply = FRC20FungibleToken.totalSupply - amount
        // emit the event
        emit TokensConvertedToFRC20(amount: amount)
        // create the change
        return <- FRC20FTShared.createChange(
            tick: self.getTickerName(),
            balance: amount,
            from: from,
            ftVault: nil
        )
    }

    access(all)
    fun getPathPrefix(): String {
        return "FRC20FungibleToken_".concat(self.account.address.toString()).concat(self.getTickerName()).concat("_")
    }

    init() {
        // Initialize the total supply to zero
        self.totalSupply = 0.0

        // Create the storage paths for the Vault and the Receiver
        let prefix = FRC20FungibleToken.getPathPrefix()
        self.VaultStoragePath = StoragePath(identifier: prefix.concat("Vault"))!
        self.VaultPublicPath = PublicPath(identifier: prefix.concat("Metadata"))!
        self.ReceiverPublicPath = PublicPath(identifier: prefix.concat("Receiver"))!

        // Create the Vault with the total supply of tokens and save it in storage.
        let vault <- create Vault(balance: self.totalSupply)
        self.account.save(<-vault, to: self.VaultStoragePath)

        // Create a public capability to the stored Vault that exposes
        // the `deposit` method through the `Receiver` interface.
        self.account.link<&{FungibleToken.Receiver}>(
            self.ReceiverPublicPath,
            target: self.VaultStoragePath
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field and the `resolveView` method through the `Balance` interface
        self.account.link<&FRC20FungibleToken.Vault{FungibleToken.Balance}>(
            self.VaultPublicPath,
            target: self.VaultStoragePath
        )

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}
