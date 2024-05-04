/**

> Author: FIXeS World <https://fixes.world/>

# FixesTokenLockDrops

This is a lockdrop service contract for the FIXeS token.
It allows users to lock their frc20/fungible tokens for a certain period of time and earn fixes token.

*/
import "FungibleToken"
import "FlowToken"
import "stFlowToken"
// FIXeS imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FixesTradablePool"
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"

/// The contract definition
///
access(all) contract FixesTokenLockDrops {

    // ------ Events -------

    // emitted when a new Drops Pool is created
    access(all) event DropsPoolCreated(
        lockingToken: String,
        dropsTokenType: Type,
        dropsTokenSymbol: String,
        createdBy: Address
    )

    /// -------- Resources and Interfaces --------

    /// Public resource interface for the Locking Center
    ///
    access(all) resource interface CeneterPublic {

    }

    /// Locking Center Resource
    ///
    access(all) resource LockingCenter: CeneterPublic {
        access(self)
        let lockingMapping: @{UInt64: {Address: FRC20FTShared.Change}}

        init() {
            self.lockingMapping <- {}
        }

        destroy() {
            destroy self.lockingMapping
        }

        // ----- Contract Level Methods -----

        // ----- Internal Methods -----

    }

    /// Public resource interface for the Drops Pool
    ///
    access(all) resource interface DropsPoolPublic {

        // ----- Basics -----

        /// Get the subject address
        access(all)
        view fun getPoolAddress(): Address {
            return self.owner?.address ?? panic("The owner is missing")
        }

        // Borrow the tradable pool
        access(all)
        view fun borrowRelavantTradablePool(): &FixesTradablePool.TradableLiquidityPool{FixesTradablePool.LiquidityPoolInterface}? {
            return FixesTradablePool.borrowTradablePool(self.getPoolAddress())
        }

        /// Check if the pool is active
        access(all)
        view fun isActivated(): Bool

        // ----- Token in the drops pool -----

        /// Get the token type
        access(all)
        view fun getTokenType(): Type

        /// Get the max supply of the token
        access(all)
        view fun getMaxSupply(): UFix64

        /// Get the circulating supply of the token
        access(all)
        view fun getCirculatingSupply(): UFix64

        /// Get the balance of the token in pool
        access(all)
        view fun getTokenBalanceInPool(): UFix64

        /// Get the locked token ticker
        access(all)
        view fun getLockedTokenTicker(): String

        /// Get the balance of the locked token
        access(all)
        view fun getLockedTokenBalance(): UFix64

        // --- Writable ---
    }

    /// Drops Pool Resource
    ///
    access(all) resource DropsPool: DropsPoolPublic, FixesFungibleTokenInterface.IMinterHolder {
        // The minter of the token
        access(self)
        let minter: @{FixesFungibleTokenInterface.IMinter}
        // The vault for the token
        access(self)
        let vault: @FungibleToken.Vault
        // The locking pool for the locking token
        access(self)
        let lockingTokenTicker: String
        // The locking exchange rates: LockingPeriod -> ExchangeRate
        access(self)
        let lockingExchangeRates: {UFix64: UFix64}
        /// When the pool is activated
        access(self)
        var activateTime: UFix64?

        init(
            _ minter: @{FixesFungibleTokenInterface.IMinter},
            _ lockingTokenTicker: String,
            _ lockingExchangeRates: {UFix64: UFix64},
            _ activateTime: UFix64?
        ) {
            self.minter <- minter
            let vaultData = self.minter.getVaultData()
            self.vault <- vaultData.createEmptyVault()
            self.lockingTokenTicker = lockingTokenTicker
            self.lockingExchangeRates = lockingExchangeRates
            self.activateTime = activateTime
        }

        // @deprecated in Cadence 1.0
        destroy() {
            destroy self.minter
            destroy self.vault
        }

        // ------ Implment DropsPoolPublic ------

        /// Check if the pool is active
        access(all)
        view fun isActivated(): Bool {
            var isActivated = true
            if self.activateTime != nil {
                isActivated = self.activateTime! <= getCurrentBlock().timestamp
            }
            if !isActivated {
                return false
            }
            // check if tradaable pool exists
            // the drops pool is activated only when the tradable pool is initialized but not active
            if let tradablePool = self.borrowRelavantTradablePool() {
                isActivated = isActivated && tradablePool.isInitialized() && !tradablePool.isLocalActive()
            }
            return isActivated
        }

        // ----- Token in the drops pool -----

        /// Get the token type
        access(all)
        view fun getTokenType(): Type {
            return self.minter.getTokenType()
        }

        /// Get the max supply of the token
        access(all)
        view fun getMaxSupply(): UFix64 {
            return self.minter.getMaxSupply()
        }

        /// Get the circulating supply of the token
        access(all)
        view fun getCirculatingSupply(): UFix64 {
            if !self.isActivated() {
                if let tradablePool = self.borrowRelavantTradablePool() {
                    return tradablePool.getCirculatingSupply()
                } else {
                    return self.minter.getTotalSupply()
                }
            } else {
                return self.minter.getTotalSupply() - self.getTokenBalanceInPool()
            }
        }

        /// Get the balance of the token in pool
        access(all)
        view fun getTokenBalanceInPool(): UFix64 {
            return self.vault.balance
        }

        /// Get the locked token ticker
        access(all)
        view fun getLockedTokenTicker(): String {
            return self.lockingTokenTicker
        }

        /// Get the balance of the locked token
        access(all)
        view fun getLockedTokenBalance(): UFix64 {
            // TODO: load from locking center
            return 0.0
        }

        // ------ Implment FixesFungibleTokenInterface.IMinterHolder ------

        access(contract)
        view fun borrowMinter(): &AnyResource{FixesFungibleTokenInterface.IMinter} {
            return &self.minter as &AnyResource{FixesFungibleTokenInterface.IMinter}
        }

        // ----- Internal Methods -----

    }

    /// ------ Public Methods ------

    /// Check if the locking tick is supported
    /// Currently, only three types of lockingTick are supported
    /// 1. empty string: the token is a flow token
    /// 2. "@A.xxx.stFlowToken.Vault": the staked flow token, powered by IncrementFi
    /// 3. "fixes": the frc20 token - fixes
    ///
    access(all)
    view fun isSupportedLockingTick(_ lockingTick: String): Bool {
        return lockingTick == "" || lockingTick == "@".concat(Type<@stFlowToken.Vault>().identifier) || lockingTick == "fixes"
    }

    /// Create an empty change for acceptable locking tick
    ///
    access(all)
    fun createEmptyChangeForLockingTick(_ lockingTick: String, _ from: Address): @FRC20FTShared.Change {
        // setup empty locking change
        var emptyChange: @FRC20FTShared.Change? <- nil
        if lockingTick == "" {
            // create an empty flow change
            emptyChange <-! FRC20FTShared.createEmptyFlowChange(from: from)
        } else if lockingTick == "@".concat(Type<@stFlowToken.Vault>().identifier) {
            // create an empty stFlowToken change
            let vault <- stFlowToken.createEmptyVault()
            emptyChange <-! FRC20FTShared.wrapFungibleVaultChange(ftVault: <- vault, from: from)
        } else if lockingTick == "fixes" {
            // create an empty fixes change
            let frc20Indexer = FRC20Indexer.getIndexer()
            assert(
                frc20Indexer.getTokenMeta(tick: lockingTick) != nil,
                message: "The FRC20 token: fixes is not found"
            )
            emptyChange <-! FRC20FTShared.createEmptyChange(tick: lockingTick, from: from)
        } else {
            panic("The locking ticker name is not supported")
        }

        if emptyChange == nil {
            panic("The empty change is not created")
        }
        return <- emptyChange!
    }

    /// Create a new Drops Pool
    ///
    access(all)
    fun createDropsPool(
        ins: &Fixes.Inscription,
        _ minter: @{FixesFungibleTokenInterface.IMinter},
        _ lockingExchangeRates: {UFix64: UFix64},
        _ activateTime: UFix64?
    ): @DropsPool {
        pre {
            ins.isExtractable(): "The inscription is not extractable"
        }
        post {
            ins.isExtracted(): "The inscription is not extracted"
        }
        // singletons
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        let meta = FixesInscriptionFactory.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        let tick = meta["tick"] ?? panic("The ticker name is not found")
        let ftContractAddr = acctsPool.getFTContractAddress(tick)
            ?? panic("The FungibleToken contract is not found")
        let minterContractAddr = minter.getContractAddress()
        assert(
            ftContractAddr == minterContractAddr,
            message: "The FungibleToken contract is not found"
        )
        assert(
            tick == "$".concat(minter.getSymbol()),
            message: "The minter capability address is not the same as the FungibleToken contract"
        )

        let lockingTick = meta["lockingTick"] ?? panic("The locking ticker name is not found")
        assert(
            self.isSupportedLockingTick(lockingTick),
            message: "The locking ticker name is not supported"
        )

        // execute the inscription
        acctsPool.executeInscription(type: FRC20AccountsPool.ChildAccountType.FungibleToken, ins)

        let tokenType = minter.getTokenType()
        let tokenSymbol = minter.getSymbol()
        let pool <- create DropsPool(<- minter, lockingTick, lockingExchangeRates, activateTime)

        // emit the created event
        emit DropsPoolCreated(
            lockingToken: lockingTick,
            dropsTokenType: tokenType,
            dropsTokenSymbol: tokenSymbol,
            createdBy: ins.owner?.address ?? panic("The inscription owner is missing")
        )

        return <- pool
    }

    /// Borrow the Locking Center
    ///
    access(all)
    view fun borrowLockingCenter(_ addr: Address): &LockingCenter{CeneterPublic}? {
        // @deprecated in Cadence 1.0
        return getAccount(addr)
            .getCapability<&LockingCenter{CeneterPublic}>(self.getLockingCenterPublicPath())
            .borrow()
    }

    /// Borrow the Drops Pool
    ///
    access(all)
    view fun borrowDropsPool(_ addr: Address): &DropsPool{DropsPoolPublic, FixesFungibleTokenInterface.IMinterHolder}? {
        // @deprecated in Cadence 1.0
        return getAccount(addr)
            .getCapability<&DropsPool{DropsPoolPublic, FixesFungibleTokenInterface.IMinterHolder}>(self.getDropsPoolPublicPath())
            .borrow()
    }

    /// Get the prefix for the storage paths
    ///
    access(all)
    view fun getPathPrefix(): String {
        return "FixesLockDrops_".concat(self.account.address.toString()).concat("_")
    }

    /// Get the storage path for the Locking Center
    ///
    access(all)
    view fun getLockingCenterStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("LockingCenter"))!
    }

    /// Get the public path for the Liquidity Pool
    ///
    access(all)
    view fun getLockingCenterPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("LockingCenter"))!
    }

    /// Get the storage path for the Locking Center
    ///
    access(all)
    view fun getDropsPoolStoragePath(): StoragePath {
        let prefix = self.getPathPrefix()
        return StoragePath(identifier: prefix.concat("DropsPool"))!
    }

    /// Get the public path for the Liquidity Pool
    ///
    access(all)
    view fun getDropsPoolPublicPath(): PublicPath {
        let prefix = self.getPathPrefix()
        return PublicPath(identifier: prefix.concat("DropsPool"))!
    }

    init() {
        self.account.save(<- create LockingCenter(), to: self.getLockingCenterStoragePath())
        self.account.link<&LockingCenter{CeneterPublic}>(
            self.getLockingCenterPublicPath(),
            target: self.getLockingCenterStoragePath()
        )
    }
}
