import "FungibleToken"

pub contract FRC20FTShared {
    /* --- Events --- */
    /// The event that is emitted when the shared store is updated
    pub event SharedStoreKeyUpdated(key: String, valueType: Type)

    /// The event that is emitted when tokens are created
    pub event TokenChangeCreated(tick:String, amount: UFix64, from: Address, changeUuid: UInt64)
    /// The event that is emitted when tokens are withdrawn from a Vault
    pub event TokenChangeWithdrawn(tick:String, amount: UFix64, from: Address, changeUuid: UInt64)
    /// The event that is emitted when tokens are deposited to a Vault
    pub event TokenChangeMerged(tick:String, amount: UFix64, from: Address, changeUuid: UInt64, fromChangeUuid: UInt64)
    /// The event that is emitted when tokens are extracted
    pub event TokenChangeExtracted(tick:String, amount: UFix64, from: Address, changeUuid: UInt64)

    /* --- Variable, Enums and Structs --- */
    access(all)
    let SharedStoreStoragePath: StoragePath
    access(all)
    let SharedStorePublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    /// Cut type for the sale
    ///
    pub enum SaleCutType: UInt8 {
        pub case SellMaker
        pub case BuyTaker
        pub case TokenTreasury
        pub case PlatformTreasury
        pub case MarketplaceStakers
        pub case MarketplaceCampaign
    }

    /// Sale cut struct for the sale
    ///
    pub struct SaleCut {
        access(all)
        let type: SaleCutType
        access(all)
        let amount: UFix64
        access(all)
        let receiver: Capability<&{FungibleToken.Receiver}>?

        init(
            type: SaleCutType,
            amount: UFix64,
            receiver: Capability<&{FungibleToken.Receiver}>?
        ) {
            if type == FRC20FTShared.SaleCutType.SellMaker {
                assert(receiver != nil, message: "Receiver should not be nil for consumer cut")
            } else {
                assert(receiver == nil, message: "Receiver should be nil for non-consumer cut")
            }
            self.type = type
            self.amount = amount
            self.receiver = receiver
        }
    }

    /// It a general interface for the Change of FRC20 Fungible Token
    ///
    pub resource interface Balance {
        /// The ticker symbol of this change
        ///
        pub let tick: String
        /// The type of the FT Vault, Optional
        ///
        pub var ftVault: @FungibleToken.Vault?
        /// The balance of this change
        ///
        pub var balance: UFix64?

        // The conforming type must declare an initializer
        // that allows providing the initial balance of the Vault
        //
        init(
            tick: String,
            balance: UFix64?,
            from: Address?,
            ftVault: @FungibleToken.Vault?
        ) {
            pre {
                balance != nil || ftVault != nil:
                    "The balance of the FT Vault or the initial balance must not be nil"
            }
            post {
                self.tick == tick: "Tick must be equal to the provided tick"
                self.balance == balance: "Balance must be equal to the initial balance"
                self.ftVault == nil || self.balance == nil:
                    "Either FT Vault or balance must be not nil"
            }
        }

        /// Get the balance of this Change
        ///
        access(all) view
        fun getBalance(): UFix64 {
            return self.ftVault?.balance ?? self.balance!
        }

        /// Check if this Change is backed by a Vault
        ///
        access(all) view
        fun isBackedByVault(): Bool {
            return self.ftVault != nil
        }

        /// Get the type of the Vault
        ///
        access(all) view
        fun getVaultType(): Type? {
            return self.ftVault?.getType()
        }
    }

    /// It a general interface for the Settler of FRC20 Fungible Token
    ///
    pub resource interface Settler {
        /// Withdraw the given amount of tokens, as a FungibleToken Vault
        ///
        access(all)
        fun withdrawAsVault(amount: UFix64): @FungibleToken.Vault {
            post {
                // `result` refers to the return value
                result.balance == amount:
                    "Withdrawal amount must be the same as the balance of the withdrawn Vault"
            }
        }

        /// Extract all balance of this Change
        ///
        access(all)
        fun extractAsVault(): @FungibleToken.Vault

        /// Extract all balance of input Change and deposit to self, this method is only available for the contracts in the same account
        ///
        access(account)
        fun merge(from: @Change)

        /// Withdraw the given amount of tokens, as a FRC20 Fungible Token Change
        ///
        access(account)
        fun withdrawAsChange(amount: UFix64): @Change {
            post {
                // `result` refers to the return value
                result.getBalance() == amount:
                    "Withdrawal amount must be the same as the balance of the withdrawn Change"
            }
        }

        /// Extract all balance of this Change
        ///
        access(account)
        fun extract(): UFix64
    }

    /// It a general resource for the Change of FRC20 Fungible Token
    ///
    pub resource Change: Balance, Settler {
        /// The ticker symbol of this change
        pub let tick: String
        /// The address of the owner of this change
        pub let from: Address
        /// The type of the FT Vault, Optional
        pub var ftVault: @FungibleToken.Vault?
        // The token balance of this Change
        pub var balance: UFix64?

        init(
            tick: String,
            balance: UFix64?,
            from: Address?,
            ftVault: @FungibleToken.Vault?
        ) {
            post {
                self.tick == tick: "Tick must be equal to the provided tick"
                balance == nil || self.from == from:
                    "Balance must be nil or the owner of the Change must be the same as the owner of the Change"
                self.balance == balance: "Balance must be equal to the initial balance"
                self.ftVault == nil || self.balance == nil:
                    "Either FT Vault or balance must be not nil"
            }
            self.tick = tick
            self.balance = balance
            // If the owner of the FT Vault is not nil, use it as the owner of the Change
            self.from = ftVault?.owner?.address ?? from ?? panic("The owner of the Change must be specified")
            self.ftVault <- ftVault

            emit TokenChangeCreated(
                tick: self.tick,
                amount: self.getBalance(),
                from: self.from,
                changeUuid: self.uuid
            )
        }

        destroy () {
            // You can not destroy a Change with a non-zero balance
            pre {
                self.getBalance() == UFix64(0): "Balance must be zero for destroy"
            }
            // Destroy the FT Vault if it is not nil
            destroy self.ftVault
        }

        /// Subtracts `amount` from the Vault's balance
        /// and returns a new Vault with the subtracted balance
        ///
        access(all)
        fun withdrawAsVault(amount: UFix64): @FungibleToken.Vault {
            pre {
                self.balance == nil: "Balance must be nil for withdrawAsVault"
                self.isBackedByVault() == true: "The Change must be backed by a Vault"
                self.ftVault?.balance! >= amount:
                    "Amount withdrawn must be less than or equal than the balance of the Vault"
            }
            post {
                // result's type must be the same as the type of the original Vault
                self.ftVault?.balance == before(self.ftVault?.balance)! - amount:
                    "New FT Vault balance must be the difference of the previous balance and the withdrawn Vault"
                // result's type must be the same as the type of the original Vault
                result.getType() == self.ftVault.getType():
                    "The type of the returned Vault must be the same as the type of the original Vault"
            }
            let vaultRef = self.borrowVault()
            let ret <- vaultRef.withdraw(amount: amount)

            emit TokenChangeWithdrawn(
                tick: self.tick,
                amount: amount,
                from: self.from,
                changeUuid: self.uuid
            )
            return <- ret
        }

        /// Extract all balance of this Change
        ///
        access(all)
        fun extractAsVault(): @FungibleToken.Vault {
            pre {
                self.isBackedByVault() == true: "The Change must be backed by a Vault"
                self.getBalance() > UFix64(0): "Balance must be greater than zero"
            }
            post {
                self.getBalance() == UFix64(0):
                    "Balance must be zero after extraction"
                result.balance == before(self.getBalance()):
                    "Extracted amount must be the same as the balance of the Change"
            }
            let vaultRef = self.borrowVault()
            let balanceToExtract = self.getBalance()
            let ret <- vaultRef.withdraw(amount: balanceToExtract)

            emit TokenChangeExtracted(
                tick: self.tick,
                amount: balanceToExtract,
                from: self.from,
                changeUuid: self.uuid
            )

            return <- ret
        }

        /// Extract all balance of input Change and deposit to self, this method is only available for the contracts in the same account
        ///
        access(account)
        fun merge(from: @Change) {
            pre {
                self.isBackedByVault() == from.isBackedByVault():
                    "The Change must be backed by a Vault if and only if the input Change is backed by a Vault"
                from.tick == self.tick: "Tick must be equal to the provided tick"
                from.from == self.from: "The owner of the Change must be the same as the owner of the Change"
            }
            post {
                self.getBalance() == before(self.getBalance()) + before(from.getBalance()):
                    "New Vault balance must be the sum of the previous balance and the deposited Vault"
            }

            var extractAmount: UFix64 = 0.0
            if self.isBackedByVault() {
                assert(
                    self.ftVault != nil && from.ftVault != nil,
                    message: "FT Vault must not be nil for merge"
                )
                let extracted <- from.extractAsVault()
                extractAmount = extracted.balance
                // Deposit the extracted Vault to self
                let vaultRef = self.borrowVault()
                vaultRef.deposit(from: <- extracted)
            } else {
                assert(
                    self.balance != nil && from.balance != nil,
                    message: "Balance must not be nil for merge"
                )
                extractAmount = from.extract()
                self.balance = self.balance! + extractAmount
            }

            // emit TokenChangeMerged event
            emit TokenChangeMerged(
                tick: self.tick,
                amount: extractAmount,
                from: self.from,
                changeUuid: self.uuid,
                fromChangeUuid: from.uuid
            )
            // Destroy the Change that we extracted from
            destroy from
        }

        /// Withdraw the given amount of tokens, as a FRC20 Fungible Token Change
        ///
        access(account)
        fun withdrawAsChange(amount: UFix64): @Change {
            pre {
                self.isBackedByVault() == false: "The Change must not be backed by a Vault"
                self.balance != nil: "Balance must not be nil for withdrawAsChange"
                self.balance! >= amount:
                    "Amount withdrawn must be less than or equal than the balance of the Vault"
            }
            post {
                // result's type must be the same as the type of the original Change
                result.tick == self.tick: "Tick must be equal to the provided tick"
                // use the special function `before` to get the value of the `balance` field
                self.balance == before(self.balance)! - amount:
                    "New Change balance must be the difference of the previous balance and the withdrawn Change"
            }
            self.balance = self.balance! - amount
            emit TokenChangeWithdrawn(
                tick: self.tick,
                amount: amount,
                from: self.from,
                changeUuid: self.uuid
            )
            return <- create Change(
                tick: self.tick,
                balance: amount,
                from: self.from,
                ftVault: nil
            )
        }

        /// Extract all balance of this Change, this method is only available for the contracts in the same account
        ///
        access(account)
        fun extract(): UFix64 {
            pre {
                !self.isBackedByVault(): "The Change must not be backed by a Vault"
                self.getBalance() > UFix64(0): "Balance must be greater than zero"
            }
            post {
                self.getBalance() == UFix64(0):
                    "Balance must be zero after extraction"
                result == before(self.getBalance()):
                    "Extracted amount must be the same as the balance of the Change"
            }
            var balanceToExtract: UFix64 = self.balance ?? panic("The balance of the Change must be specified")
            self.balance = 0.0

            emit TokenChangeExtracted(
                tick: self.tick,
                amount: balanceToExtract,
                from: self.from,
                changeUuid: self.uuid
            )
            return balanceToExtract
        }

        /// Borrow the underlying Vault of this Change
        ///
        access(self)
        fun borrowVault(): &FungibleToken.Vault {
            return &self.ftVault as &FungibleToken.Vault?
                ?? panic("The Change is not backed by a Vault")
        }
    }

    /** --- Temporary order resources --- */

    /// It a temporary resource combining change and cuts
    ///
    pub resource ValidFrozenOrder {
        pub let cuts: [SaleCut]
        pub var change: @Change?

        init(_ change: @Change, cuts: [SaleCut]) {
            pre {
                cuts.length > 0: "Cuts must not be empty"
                change.getBalance() > UFix64(0): "Balance must be greater than zero"
            }
            self.change <- change
            self.cuts = cuts
        }
        destroy () {
            pre {
                self.change == nil: "Change must be nil for destroy"
            }
            destroy self.change
        }

        /// Extract all balance of this Change, this method is only available for the contracts in the same account
        ///
        access(account)
        fun extract(): @Change {
            pre {
                self.change != nil: "Change must not be nil for extract"
            }
            post {
                self.change == nil: "Change must be nil after extraction"
                result.getBalance() == before(self.change?.getBalance()):
                    "Extracted amount must be the same as the balance of the Change"
            }
            var out: @Change? <- nil
            self.change <-> out
            return <- out!
        }
    }

    /** Shared store resource */

    pub resource interface SharedStorePublic {
        // getter for the shared store
        access(all)
        fun get(_ key: String): AnyStruct?
    }

    pub resource SharedStore: SharedStorePublic {
        access(self)
        var data: {String: AnyStruct}

        init() {
            self.data = {}
        }

        // getter for the shared store
        access(all)
        fun get(_ key: String): AnyStruct? {
            return self.data[key]
        }

        // setter for the shared store
        access(account)
        fun set(_ key: String, value: AnyStruct) {
            self.data[key] = value

            emit SharedStoreKeyUpdated(key: key, valueType: value.getType())
        }
    }

    /* --- Public Methods --- */

    /// Get the shared store
    ///
    access(all)
    fun borrowStoreRef(): &SharedStore{SharedStorePublic} {
        let addr = self.account.address
        return getAccount(addr)
            .getCapability<&SharedStore{SharedStorePublic}>(self.SharedStorePublicPath)
            .borrow() ?? panic("Could not borrow capability from public store")
    }

    /* --- Account Methods --- */

    /// Only the contracts in this account can call this method
    ///
    access(account)
    fun createValidFrozenOrder(
        change: @Change,
        cuts: [SaleCut],
    ): @ValidFrozenOrder {
        return <- create ValidFrozenOrder(
            <- change,
            cuts: cuts
        )
    }

    /// Only the owner of the account can call this method
    ///
    access(account)
    fun createChange(
        tick: String,
        balance: UFix64?,
        from: Address?,
        ftVault: @FungibleToken.Vault?
    ): @Change {
        return <- create Change(
            tick: tick,
            balance: balance,
            from: from,
            ftVault: <-ftVault
        )
    }

    init() {
        let identifier = "FRC20SharedStore_".concat(self.account.address.toString())
        self.SharedStoreStoragePath = StoragePath(identifier: identifier)!
        self.SharedStorePublicPath = PublicPath(identifier: identifier)!
        // create the indexer
        self.account.save(<- create SharedStore(), to: self.SharedStoreStoragePath)
        self.account.link<&SharedStore{SharedStorePublic}>(self.SharedStorePublicPath, target: self.SharedStoreStoragePath)
    }
}
