import "FungibleToken"

pub contract FRC20FTShared {
    /* --- Events --- */

    /// The event that is emitted when tokens are created
    pub event TokenChangeCreated(tick:String, amount: UFix64, from: Address)
    /// The event that is emitted when tokens are withdrawn from a Vault
    pub event TokenChangeWithdrawn(tick:String, amount: UFix64, from: Address)
    /// The event that is emitted when tokens are extracted
    pub event TokenChangeExtracted(tick:String, amount: UFix64, from: Address)

    /* --- Interfaces & Resources --- */

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
            pre {
                ftVault == nil || ftVault?.owner?.address ?? from != nil:
                    "The owner of the FT Vault or the owner of the Change must not be nil"
            }
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

            emit TokenChangeCreated(tick: self.tick, amount: self.getBalance(), from: self.from)
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
                self.ftVault != nil: "FT Vault must not be nil for withdrawAsVault"
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
            emit TokenChangeWithdrawn(tick: self.tick, amount: amount, from: self.from)
            return <- ret
        }

        /// Withdraw the given amount of tokens, as a FRC20 Fungible Token Change
        ///
        access(account)
        fun withdrawAsChange(amount: UFix64): @Change {
            pre {
                self.ftVault == nil: "FT Vault must be nil for withdrawAsChange"
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
            emit TokenChangeWithdrawn(tick: self.tick, amount: amount, from: self.from)
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
                self.ftVault == nil: "FT Vault must be nil for extract"
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
            emit TokenChangeExtracted(tick: self.tick, amount: balanceToExtract, from: self.from)
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

    /* --- Account Methods --- */

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
}
