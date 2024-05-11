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

    // emitted when a new token is locked
    access(all) event TokenLocked(
        poolAddr: Address,
        userAddr: Address,
        lockedTokenTicker: String,
        lockedTokenType: Type?,
        lockedAmount: UFix64,
        lockingPeriod: UFix64,
        unlockTime: UFix64
    )

    // emitted when the locked token is unlocked
    access(all) event TokenUnlocked(
        poolAddr: Address,
        userAddr: Address,
        lockedTokenTicker: String,
        lockedTokenType: Type?,
        lockedAmount: UFix64
    )

    // emitted when the drops are prepared
    access(all) event TokenDropsPrepared(
        poolAddr: Address,
        userAddr: Address,
        lockedTokenTicker: String,
        lockedTokenType: Type?,
        lockedAmount: UFix64,
        dropsTokenType: Type,
        dropsTokenAmount: UFix64,
    )

    // emitted when the drops are claimed
    access(all) event TokenDropsClaimed(
        poolAddr: Address,
        userAddr: Address,
        dropsTokenType: Type,
        dropsTokenAmount: UFix64
    )

    // emitted when a new Drops Pool is created
    access(all) event LockDropsPoolCreated(
        lockingToken: String,
        dropsTokenType: Type,
        dropsTokenSymbol: String,
        minterGrantedAmount: UFix64,
        createdBy: Address
    )

    /// -------- Resources and Interfaces --------

    /// Locking Entry Resource
    ///
    access(all) resource LockingEntry {
        access(self)
        let locked: @FRC20FTShared.Change
        access(all)
        let unlockTime: UFix64

        init(
            _ change: @FRC20FTShared.Change,
            _ unlockTime: UFix64
        ) {
            self.locked <- change
            self.unlockTime = unlockTime
        }

        destroy() {
            destroy self.locked
        }

        /// Get the locked balance
        ///
        access(contract)
        view fun getLockedBalance(): UFix64 {
            return self.locked.getBalance()
        }

        /// Check if the entry is unlocked
        ///
        access(contract)
        view fun isUnlocked(): Bool {
            return self.unlockTime <= getCurrentBlock().timestamp
        }

        /// Withdraw all the locked balance
        ///
        access(contract)
        fun extractLockedChange(): @FRC20FTShared.Change {
            pre {
                self.isUnlocked(): "The entry is not unlocked"
            }
            post {
                self.locked.getBalance() == 0.0: "The locked balance is not zero"
                result.getBalance() == before(self.locked.getBalance()): "The balance is not matched"
            }
            return <- self.locked.withdrawAsChange(amount: self.locked.getBalance())
        }
    }

    /// User Locking Info Resource
    ///
    access(all) resource UserLockingInfo {
        access(self)
        let belongsTo: Address
        access(self)
        let entries: @[LockingEntry]

        init(
            _ belongsTo: Address
        ) {
            self.belongsTo = belongsTo
            self.entries <- []
        }

        destroy() {
            destroy self.entries
        }

        access(contract)
        view fun getTotalLockedBalance(): UFix64 {
            var total: UFix64 = 0.0
            var i = self.entries.length
            while i > 0 {
                i = i - 1
                total = total + self.entries[i].getLockedBalance()
            }
            return total
        }

        /// Check if the user has unlocked entries
        ///
        access(contract)
        view fun hasUnlockedEntries(): Bool {
            if self.entries.length == 0 {
                return false
            }
            return self.entries[0].isUnlocked()
        }

        /// Get the unlocked balance
        ///
        access(contract)
        view fun getUnlockedBalance(): UFix64 {
            if !self.hasUnlockedEntries() {
                return 0.0
            }
            var total = 0.0
            var i = 0
            while i < self.entries.length {
                if self.entries[i].isUnlocked() {
                    total = total + self.entries[i].getLockedBalance()
                } else {
                    break
                }
                i = i + 1
            }
            return total
        }

        /// Add a new entry
        ///
        access(contract)
        fun addEntry(_ entry: @FRC20FTShared.Change, _ lockingPeriod: UFix64) {
            pre {
                entry.from == self.belongsTo: "The entry is not owned by the user: ".concat(self.belongsTo.toString())
            }
            let unlockTime = getCurrentBlock().timestamp + lockingPeriod
            // find the proper index to insert the new entry based on the unlock time
            var idx = 0
            while idx < self.entries.length {
                if self.entries[idx].unlockTime > unlockTime {
                    break
                }
                idx = idx + 1
            }
            // insert the new entry
            self.entries.insert(at: idx, <- create LockingEntry(<- entry, unlockTime))
        }

        /// Release the unlocked entries
        ///
        access(contract)
        fun releaseUnlockedEntries(force: Bool): @FRC20FTShared.Change? {
            var unlocked: @FRC20FTShared.Change? <- nil
            while self.entries.length > 0 && (self.entries[0].isUnlocked() || force == true) {
                let entry <- self.entries.remove(at: 0)
                if unlocked == nil {
                    unlocked <-! entry.extractLockedChange()
                } else {
                    unlocked?.merge(from: <- entry.extractLockedChange())
                }
                // destroy entry
                destroy entry
            }
            return <- unlocked!
        }

        /// --- Internal Methods ---

        access(self)
        view fun borrowLockingEntry(_ idx: Int): &LockingEntry? {
            if idx >= 0 && idx < self.entries.length {
                return &self.entries[idx] as &LockingEntry
            }
            return nil
        }
    }

    /// Public resource interface for the Locking Center
    ///
    access(all) resource interface CeneterPublic {
        /// Get the locked token ticker
        access(all)
        view fun getLockingTokenTicker(_ poolAddr: Address): String?
        /// Get the locked token balance
        access(all)
        view fun getLockedTokenBalance(_ poolAddr: Address, _ userAddr: Address): UFix64
        /// Get the total locked token balance
        access(all)
        view fun getTotalLockedTokenBalance(_ poolAddr: Address): UFix64
        /// Check if the user has joined the pool
        access(all)
        view fun isUserJoinedPool(_ poolAddr: Address, _ userAddr: Address): Bool
        /// Get the user joined pools
        access(all)
        view fun getUserJoinedPools(_ userAddr: Address): [Address]
        /// Check if the user has unlocked entries
        access(all)
        view fun hasUnlockedEntries(_ poolAddr: Address, _ userAddr: Address): Bool
        /// Get the unlocked balance
        access(all)
        view fun getUnlockedBalance(_ poolAddr: Address, _ userAddr: Address): UFix64

        // --- Writable ---

        /// Lock the change to the locking center
        access(contract)
        fun lock(
            _ poolAddr: Address,
            entry: @FRC20FTShared.Change,
            lockingPeriod: UFix64
        )

        /// Release the unlocked entries
        access(contract)
        fun releaseUnlockedEntries(_ poolAddr: Address, _ userAddr: Address, force: Bool): @FRC20FTShared.Change?
    }

    /// Locking Center Resource
    ///
    access(all) resource LockingCenter: CeneterPublic {
        /// The locking mapping: PoolAddress -> UserAddress -> UserLockingInfo
        access(self)
        let lockingMapping: @{Address: {Address: UserLockingInfo}}
        /// The joined pools: UserAddress -> [PoolAddress]
        access(self)
        let joinedPools: {Address: [Address]}

        init() {
            self.lockingMapping <- {}
            self.joinedPools = {}
        }

        destroy() {
            destroy self.lockingMapping
        }

        // ------ Implment CeneterPublic ------

        /// Get the locked token ticker
        ///
        access(all)
        view fun getLockingTokenTicker(_ poolAddr: Address): String? {
            if let pool = FixesTokenLockDrops.borrowDropsPool(poolAddr) {
                return pool.getLockingTokenTicker()
            }
            return nil
        }

        /// Get the locked token balance
        ///
        access(all)
        view fun getLockedTokenBalance(_ poolAddr: Address, _ userAddr: Address): UFix64 {
            if let info = self.borrowLockingInfo(poolAddr, userAddr) {
                return info.getTotalLockedBalance()
            }
            return 0.0
        }

        /// Get the total locked token balance
        ///
        access(all)
        view fun getTotalLockedTokenBalance(_ poolAddr: Address): UFix64 {
            var total: UFix64 = 0.0
            if let dictRef = self.borrowLockedDict(poolAddr) {
                for userAddr in dictRef.keys {
                    if let infoRef = &dictRef[userAddr] as &UserLockingInfo? {
                        total = total + infoRef.getTotalLockedBalance()
                    }
                }
            }
            return total
        }

        /// Check if the user has joined the pool
        ///
        access(all)
        view fun isUserJoinedPool(_ poolAddr: Address, _ userAddr: Address): Bool {
            if let dictRef = self.borrowLockedDict(poolAddr) {
                return dictRef[userAddr] != nil
            }
            return false
        }

        /// Get the user joined pools
        ///
        access(all)
        view fun getUserJoinedPools(_ userAddr: Address): [Address] {
            return self.joinedPools[userAddr] ?? []
        }

        /// Check if the user has unlocked entries
        access(all)
        view fun hasUnlockedEntries(_ poolAddr: Address, _ userAddr: Address): Bool {
            if let info = self.borrowLockingInfo(poolAddr, userAddr) {
                return info.hasUnlockedEntries()
            }
            return false
        }

        /// Get the unlocked balance
        access(all)
        view fun getUnlockedBalance(_ poolAddr: Address, _ userAddr: Address): UFix64 {
            if let info = self.borrowLockingInfo(poolAddr, userAddr) {
                return info.getUnlockedBalance()
            }
            return 0.0
        }

        /// Lock the change to the locking center
        access(contract)
        fun lock(
            _ poolAddr: Address,
            entry: @FRC20FTShared.Change,
            lockingPeriod: UFix64
        ) {
            pre {
                self.getLockingTokenTicker(poolAddr) == entry.tick:
                    "The locked token ticker is not matched"
            }

            let userAddr = entry.from
            let userLockingTicker = entry.tick
            let userLockingType = entry.isBackedByVault() ? entry.getVaultType() : nil
            let userLockingAmount = entry.getBalance()

            // check if the pool dict exists
            if self.lockingMapping[poolAddr] == nil {
                self.lockingMapping[poolAddr] <-! {}
            }
            let poolDict = self.borrowLockedDict(poolAddr) ?? panic("The pool dict is missing")

            // check if the user has joined the pool
            if poolDict[userAddr] == nil {
                // create a new user locking info
                let info <- create UserLockingInfo(userAddr)
                poolDict[userAddr] <-! info
            }
            let userLockingRef = &poolDict[userAddr] as &UserLockingInfo?
                ?? panic("The user locking info is missing")

            // lock the change
            userLockingRef.addEntry(<- entry, lockingPeriod)

            // add the pool to the user's joined pools
            if self.joinedPools[userAddr] == nil {
                self.joinedPools[userAddr] == []
            }
            let userJoinedPools = self.borrowUserJoinedPools(userAddr) ?? panic("The user joined pools is missing")
            if !userJoinedPools.contains(poolAddr) {
                userJoinedPools.append(poolAddr)
            }

            // emit the token locked event
            emit TokenLocked(
                poolAddr: poolAddr,
                userAddr: userAddr,
                lockedTokenTicker: userLockingTicker,
                lockedTokenType: userLockingType,
                lockedAmount: userLockingAmount,
                lockingPeriod: lockingPeriod,
                unlockTime: getCurrentBlock().timestamp + lockingPeriod
            )
        }

        /// Release the unlocked entries
        /// - force: this is used to force the release of the unlocked entries, only can be called when the pool is deactivated
        access(contract)
        fun releaseUnlockedEntries(_ poolAddr: Address, _ userAddr: Address, force: Bool): @FRC20FTShared.Change? {
            post {
                result == nil || result?.tick == self.getLockingTokenTicker(poolAddr): "The locked token ticker is not matched"
            }
            let userLockingRef = self.borrowLockingInfo(poolAddr, userAddr)
                ?? panic("The user locking info is missing")

            if force == true {
                let pool = FixesTokenLockDrops.borrowDropsPool(poolAddr)
                    ?? panic("The pool is missing")
                assert(
                    pool.isDeprecated(),
                    message: "The pool is not deactivated"
                )
            }

            let unlock <- userLockingRef.releaseUnlockedEntries(force: force)

            // emit the token unlocked event
            if unlock != nil {
                emit TokenUnlocked(
                    poolAddr: poolAddr,
                    userAddr: userAddr,
                    lockedTokenTicker: unlock?.tick!,
                    lockedTokenType: unlock?.isBackedByVault() == true ? unlock?.getVaultType()! : nil,
                    lockedAmount: unlock?.getBalance() ?? 0.0
                )
            }
            return <- unlock
        }

        // ----- Internal Methods -----

        /// Borrow the locking dict
        ///
        access(self)
        view fun borrowLockedDict(_ poolAddr: Address): &{Address: UserLockingInfo}? {
            return &self.lockingMapping[poolAddr] as &{Address: UserLockingInfo}?
        }

        /// Borrow the locked token change
        ///
        access(self)
        view fun borrowLockingInfo(_ poolAddr: Address, _ userAddr: Address): &UserLockingInfo? {
            if let poolDict = self.borrowLockedDict(poolAddr) {
                return &poolDict[userAddr] as &UserLockingInfo?
            }
            return nil
        }

        access(self)
        view fun borrowUserJoinedPools(_ userAddr: Address): &[Address]? {
            return &self.joinedPools[userAddr] as &[Address]?
        }
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

        /// Check if the pool is claimable
        access(all)
        view fun isClaimable(): Bool

        /// Check if the pool is deactivated
        access(all)
        view fun isDeprecated(): Bool

        // ----- Token in the drops pool -----

        /// Get the balance of the token in pool
        access(all)
        view fun getUnclaimedBalanceInPool(): UFix64

        /// Get the total locked token balance
        access(all)
        view fun getTotalLockedTokenBalance(): UFix64

        /// Get the balance of the locked token
        access(all)
        view fun getLockedTokenBalance(_ userAddr: Address): UFix64

        /// Check if the user has unlocked entries
        access(all)
        view fun hasUnlockedToken(_ userAddr: Address): Bool

        /// Get the unlocked balance
        access(all)
        view fun getUnlockedBalance(_ userAddr: Address): UFix64

        /// Get the claimable amount
        access(all)
        view fun getClaimableTokenAmount(_ userAddr: Address): UFix64

        // ----- Locking Parameters -----

        /// Get the locked token ticker
        access(all)
        view fun getLockingTokenTicker(): String

        access(all)
        view fun getLockingPeriods(): [UFix64]

        access(all)
        view fun getExchangeRate(_ lockingPeriod: UFix64): UFix64

        // --- Writable ---

        /// Locking for token drops
        access(all)
        fun lockAndMint(
            _ ins: &Fixes.Inscription,
            lockingPeriod: UFix64,
            lockingVault: @FungibleToken.Vault?,
        ) {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
                self.isActivated(): "You can not lock the token when the pool is not activated"
                !self.isClaimable(): "You can not lock the token when the pool is claimable"
            }
            post {
                ins.isExtracted(): "The inscription is not extracted"
            }
        }

        /// Claim drops token
        access(all)
        fun claimDrops(
            _ ins: &Fixes.Inscription,
            recipient: &{FungibleToken.Receiver},
        ) {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
                self.isActivated(): "You can not lock the token when the pool is not activated"
                self.isClaimable(): "You can not claim the token when the pool is not claimable"
            }
            post {
                ins.isExtracted(): "The inscription is not extracted"
            }
        }

        /// Claim unlocked tokens
        ///
        access(all)
        fun claimUnlockedTokens(
            _ ins: &Fixes.Inscription,
            recipient: &{FungibleToken.Receiver}?,
        ) {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
                self.isActivated(): "You can not lock the token when the pool is not activated"
                self.isDeprecated() || self.hasUnlockedToken(ins.owner?.address ?? panic("The owner is missing")): "You can not claim the token when the pool is not deprecated or the user has no unlocked entries"
            }
            post {
                ins.isExtracted(): "The inscription is not extracted"
            }
        }
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
        // Address => Record
        access(self)
        let claimableRecords: {Address: UFix64}
        // The locking pool for the locking token
        access(self)
        let lockingTokenTicker: String
        // The locking exchange rates: LockingPeriod -> ExchangeRate
        access(self)
        let lockingExchangeRates: {UFix64: UFix64}
        /// When the pool is activated
        access(self)
        var activateTime: UFix64?
        /// When the pool is deactivated if the activation fails
        access(self)
        var failureDeprecatedTime: UFix64?

        init(
            _ minter: @{FixesFungibleTokenInterface.IMinter},
            _ lockingTokenTicker: String,
            _ lockingExchangeRates: {UFix64: UFix64},
            activateTime: UFix64?,
            failureDeprecatedTime: UFix64?
        ) {
            pre {
                minter.getTotalAllowedMintableAmount() > 0.0: "The mint amount must be greater than 0"
            }
            for one in lockingExchangeRates.keys {
                assert(
                    lockingExchangeRates[one]! > 0.0,
                    message: "The exchange rate should be greater than zero"
                )
            }
            self.minter <- minter
            let vaultData = self.minter.getVaultData()
            self.vault <- vaultData.createEmptyVault()
            self.claimableRecords = {}
            self.lockingTokenTicker = lockingTokenTicker
            self.lockingExchangeRates = lockingExchangeRates
            self.activateTime = activateTime
            self.failureDeprecatedTime = failureDeprecatedTime
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
            return isActivated
        }

        /// Check if the pool is claimable
        access(all)
        view fun isClaimable(): Bool {
            if !self.isActivated() {
                return false
            }
            // check if tradable pool exists
            // the drops pool is activated only when the tradable pool is initialized but not active
            if let tradablePool = self.borrowRelavantTradablePool() {
                return tradablePool.isInitialized() && !tradablePool.isLocalActive()
            }
            return true
        }

        /// Check if the pool is deactivated
        access(all)
        view fun isDeprecated(): Bool {
            var isDeprecated = false
            if self.failureDeprecatedTime != nil {
                isDeprecated = self.failureDeprecatedTime! <= getCurrentBlock().timestamp
            }
            if !isDeprecated {
                return false
            }
            // check if tradable pool exists
            // the drops pool is deactivated only after the tradable pool is active
            if let tradablePool = self.borrowRelavantTradablePool() {
                isDeprecated = isDeprecated && tradablePool.isInitialized() && tradablePool.isLocalActive()
            }
            return isDeprecated
        }

        // ----- Token in the drops pool -----

        /// Get the balance of the token in pool
        access(all)
        view fun getUnclaimedBalanceInPool(): UFix64 {
            return self.vault.balance
        }

        /// Get the total locked token balance
        //
        access(all)
        view fun getTotalLockedTokenBalance(): UFix64 {
            let center = FixesTokenLockDrops.borrowLockingCenter()
            return center.getTotalLockedTokenBalance(self.getPoolAddress())
        }

        /// Get the balance of the locked token
        access(all)
        view fun getLockedTokenBalance(_ userAddr: Address): UFix64 {
            let center = FixesTokenLockDrops.borrowLockingCenter()
            return center.getLockedTokenBalance(self.getPoolAddress(), userAddr)
        }

        /// Check if the user has unlocked entries
        ///
        access(all)
        view fun hasUnlockedToken(_ userAddr: Address): Bool {
            let center = FixesTokenLockDrops.borrowLockingCenter()
            return center.hasUnlockedEntries(self.getPoolAddress(), userAddr)
        }

        /// Get the unlocked balance
        access(all)
        view fun getUnlockedBalance(_ userAddr: Address): UFix64 {
            let center = FixesTokenLockDrops.borrowLockingCenter()
            return center.getUnlockedBalance(self.getPoolAddress(), userAddr)
        }

        /// Get the claimable amount
        access(all)
        view fun getClaimableTokenAmount(_ userAddr: Address): UFix64 {
            return self.claimableRecords[userAddr] ?? 0.0
        }

        /// Get the locked token ticker
        access(all)
        view fun getLockingTokenTicker(): String {
            return self.lockingTokenTicker
        }

        /// Get the locking periods
        access(all)
        view fun getLockingPeriods(): [UFix64] {
            return self.lockingExchangeRates.keys
        }

        /// Get the exchange rate for the locking period
        access(all)
        view fun getExchangeRate(_ lockingPeriod: UFix64): UFix64 {
            return self.lockingExchangeRates[lockingPeriod] ?? 0.0
        }

        // ------ Writeable ------

        /// Locking for token drops
        ///
        access(all)
        fun lockAndMint(
            _ ins: &Fixes.Inscription,
            lockingPeriod: UFix64,
            lockingVault: @FungibleToken.Vault?,
        ) {
            pre {
                self.lockingExchangeRates[lockingPeriod] != nil: "The locking period is not supported"
            }
            let minter = self.borrowMinter()
            let callerAddr = ins.owner?.address ?? panic("The owner is missing")

            // check the locking token
            let locking <- FixesTokenLockDrops.createEmptyChangeForLockingTick(
                self.lockingTokenTicker,
                callerAddr
            )

            // check if it is FlowToken or stFlowToken
            if locking.isBackedByVault() {
                assert(
                    lockingVault != nil,
                    message: "The vault is missing"
                )
                assert(
                    locking.getVaultType() == lockingVault?.getType()!,
                    message: "The vault type is not matched"
                )
                locking.merge(from: <- FRC20FTShared.wrapFungibleVaultChange(ftVault: <- lockingVault!, from: callerAddr))
                // execute the inscription
                FixesTradablePool.verifyAndExecuteInscription(
                    ins,
                    symbol: minter.getSymbol(),
                    usage: "lock-drop"
                )
            } else {
                assert(
                    lockingVault == nil,
                    message: "The vault is not needed"
                )
                destroy lockingVault
                // here is for FRC20 token
                let frc20Indexer = FRC20Indexer.getIndexer()
                // inscription should be op=withdraw for withdraw frc20 token
                let withdrawChange <- frc20Indexer.withdrawChange(ins: ins)
                assert(
                    withdrawChange.tick == self.lockingTokenTicker,
                    message: "The locking token ticker is not matched"
                )
                locking.merge(from: <- withdrawChange)
            }

            // calculate how many tokens to mint
            let exchangeRate = self.lockingExchangeRates[lockingPeriod]!
            var mintAmount = locking.getBalance() * exchangeRate
            let maxMintAmount = self.minter.getCurrentMintableAmount()
            if mintAmount > maxMintAmount {
                mintAmount = maxMintAmount
            }

            // mint the tokens and deposit to the vault
            self.vault.deposit(from: <- self.minter.mintTokens(amount: mintAmount))
            // add the claimable record
            self.claimableRecords[callerAddr] = mintAmount + (self.claimableRecords[callerAddr] ?? 0.0)

            // emit drops prepared event
            emit TokenDropsPrepared(
                poolAddr: self.getPoolAddress(),
                userAddr: callerAddr,
                lockedTokenTicker: locking.tick,
                lockedTokenType: locking.isBackedByVault() ? locking.getVaultType() : nil,
                lockedAmount: locking.getBalance(),
                dropsTokenType: self.minter.getTokenType(),
                dropsTokenAmount: mintAmount
            )

            // lock the token
            let center = FixesTokenLockDrops.borrowLockingCenter()
            center.lock(
                self.getPoolAddress(),
                entry: <- locking,
                lockingPeriod: lockingPeriod
            )
        }

        /// Claim drops token
        ///
        access(all)
        fun claimDrops(
            _ ins: &Fixes.Inscription,
            recipient: &{FungibleToken.Receiver},
        ) {
            let callerAddr = ins.owner?.address ?? panic("The owner is missing")

            // check the claimable amount
            let claimableAmount = self.claimableRecords[callerAddr] ?? 0.0
            assert(
                claimableAmount > 0.0,
                message: "The claimable amount is zero"
            )
            assert(
                claimableAmount <= self.vault.balance,
                message: "The claimable amount is greater than the vault balance"
            )

            let supportedTokens = recipient.getSupportedVaultTypes()
            let tokenType = self.vault.getType()
            assert(
                supportedTokens[tokenType] == true,
                message: "The recipient does not support the token type"
            )

            // withdraw the claimable amount from the vault
            let newVault <- self.vault.withdraw(amount: claimableAmount)
            // update the claimable record
            self.claimableRecords[callerAddr] = 0.0

            // initialize the vault by inscription, op=exec
            let initializedVault <- self.minter.initializeVaultByInscription(
                vault: <- newVault,
                ins: ins
            )
            recipient.deposit(from: <- initializedVault)

            // emit the drops claimed event
            emit TokenDropsClaimed(
                poolAddr: self.getPoolAddress(),
                userAddr: callerAddr,
                dropsTokenType: tokenType,
                dropsTokenAmount: claimableAmount
            )
        }

        /// Claim unlocked tokens
        ///
        access(all)
        fun claimUnlockedTokens(
            _ ins: &Fixes.Inscription,
            recipient: &{FungibleToken.Receiver}?,
        ) {
            let callerAddr = ins.owner?.address ?? panic("The owner is missing")

            let center = FixesTokenLockDrops.borrowLockingCenter()

            // first we need to release the unlocked entries, for deparecated pool, we need to force the release
            if let releasedEntry <- center.releaseUnlockedEntries(
                self.getPoolAddress(),
                callerAddr,
                force: self.isDeprecated()
            ) {
                let stFlowType = Type<@stFlowToken.Vault>()
                let stFlowTicker = "@".concat(stFlowType.identifier)
                // for stFlowToken, we need to deposit the released entry to the recipient
                if self.lockingTokenTicker == stFlowTicker {
                    assert(
                        recipient != nil,
                        message: "The recipient is missing"
                    )
                    assert(
                        releasedEntry.isBackedByVault() && releasedEntry.getType() == stFlowType,
                        message: "The released entry is not stFlowToken"
                    )
                    let accepts = recipient?.getSupportedVaultTypes() ?? {}
                    assert(
                        accepts[stFlowType] == true,
                        message: "The recipient does not support the stFlowToken"
                    )
                    // deposit the released entry to the recipient
                    recipient!.deposit(from: <- releasedEntry.extractAsVault())
                    destroy releasedEntry
                } else {
                    // for FRC20 token and Flow, we can use FRC20Indexer.return
                    let frc20Indexer = FRC20Indexer.getIndexer()
                    frc20Indexer.returnChange(change: <- releasedEntry)
                }
                // execute the inscription
                FixesTradablePool.verifyAndExecuteInscription(
                    ins,
                    symbol: self.minter.getSymbol(),
                    usage: "claim-unlocked"
                )
            } // enf if
            // if no released entry, we do nothing
        }

        // ------ Implment FixesFungibleTokenInterface.IMinterHolder ------

        /// Get the circulating supply of the token
        access(all)
        view fun getCirculatingSupply(): UFix64 {
            if !self.isClaimable() {
                if let tradablePool = self.borrowRelavantTradablePool() {
                    return tradablePool.getTradablePoolCirculatingSupply()
                } else {
                    return self.minter.getTotalSupply()
                }
            } else {
                return self.minter.getTotalSupply() - self.getUnclaimedBalanceInPool()
            }
        }

        access(contract)
        view fun borrowMinter(): &{FixesFungibleTokenInterface.IMinter} {
            return &self.minter as &{FixesFungibleTokenInterface.IMinter}
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
        let utilityTick = FRC20FTShared.getPlatformUtilityTickerName()
        return lockingTick == "" || lockingTick == "@".concat(Type<@stFlowToken.Vault>().identifier) || lockingTick == utilityTick
    }

    /// Create an empty change for acceptable locking tick
    ///
    access(all)
    fun createEmptyChangeForLockingTick(_ lockingTick: String, _ from: Address): @FRC20FTShared.Change {
        // setup empty locking change
        var emptyChange: @FRC20FTShared.Change? <- nil
        let utilityTick = FRC20FTShared.getPlatformUtilityTickerName()
        if lockingTick == "" {
            // create an empty flow change
            emptyChange <-! FRC20FTShared.createEmptyFlowChange(from: from)
        } else if lockingTick == "@".concat(Type<@stFlowToken.Vault>().identifier) {
            // create an empty stFlowToken change
            let vault <- stFlowToken.createEmptyVault()
            emptyChange <-! FRC20FTShared.wrapFungibleVaultChange(ftVault: <- vault, from: from)
        } else if lockingTick == utilityTick {
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
    access(account)
    fun createDropsPool(
        _ ins: &Fixes.Inscription,
        _ minter: @{FixesFungibleTokenInterface.IMinter},
        _ lockingExchangeRates: {UFix64: UFix64},
        _ activateTime: UFix64?,
        _ failureDeprecatedTime: UFix64?
    ): @DropsPool {
        pre {
            ins.isExtractable(): "The inscription is not extractable"
        }
        post {
            ins.isExtracted(): "The inscription is not extracted"
        }

        // verify the inscription and get the meta data
        let meta =  FixesTradablePool.verifyAndExecuteInscription(
            ins,
            symbol: minter.getSymbol(),
            usage: "*"
        )

        let lockingTick = meta["lockingTick"] ?? panic("The locking ticker name is not found")
        assert(
            self.isSupportedLockingTick(lockingTick),
            message: "The locking ticker name is not supported"
        )

        let tokenType = minter.getTokenType()
        let tokenSymbol = minter.getSymbol()
        let grantedAmount = minter.getCurrentMintableAmount()
        let pool <- create DropsPool(
            <- minter,
            lockingTick,
            lockingExchangeRates,
            activateTime: activateTime,
            failureDeprecatedTime: failureDeprecatedTime
        )

        // emit the created event
        emit LockDropsPoolCreated(
            lockingToken: lockingTick,
            dropsTokenType: tokenType,
            dropsTokenSymbol: tokenSymbol,
            minterGrantedAmount: grantedAmount,
            createdBy: ins.owner?.address ?? panic("The inscription owner is missing")
        )

        return <- pool
    }

    /// Borrow the Locking Center
    ///
    access(all)
    view fun borrowLockingCenter(): &LockingCenter{CeneterPublic} {
        // @deprecated in Cadence 1.0
        return getAccount(self.account.address)
            .getCapability<&LockingCenter{CeneterPublic}>(self.getLockingCenterPublicPath())
            .borrow()
            ?? panic("The Locking Center is missing")
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
