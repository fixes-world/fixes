/**
> Author: Fixes Lab <https://github.com/fixes-world/>

# FRC20 Staking Manager

The staking manager contract is responsible for managing the staking pools and the staking process.
It allows users to stake their FRC20 tokens, unstake them, claim rewards, and donate tokens to the staking pools.

*/
// Third Party Imports
import "FungibleToken"
import "FlowToken"
import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"
import "Burner"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesHeartbeat"
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20SemiNFT"
import "FRC20AccountsPool"
import "FRC20Staking"
import "FRC20StakingVesting"
import "FRC20StakingForwarder"

access(all) contract FRC20StakingManager {

    access(all) entitlement Admin
    access(all) entitlement Manage

    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()
    /// Event emitted when the whitelist is updated
    access(all) event StakingWhitelistUpdated(address: Address, isWhitelisted: Bool)
    /// Event emitted when a staking pool is enabled
    access(all) event StakingPoolEnabled(tick: String, address: Address, by: Address)
    /// Event emitted when a staking pool resources are updated
    access(all) event StakingPoolResourcesUpdated(tick: String, address: Address, by: Address)
    /// Event emitted when a reward strategy is registered
    access(all) event StakingPoolRewardStrategyRegistered(tick: String, rewardTick: String, by: Address)
    /// Event emitted when a staking pool is donated
    access(all) event StakingPoolDonated(tick: String, rewardTick: String, amount: UFix64, by: Address)
    /// Event emitted when a staking pool is donated as vesting
    access(all) event StakingPoolDonatedAsVesting(tick: String, rewardTick: String, amount: UFix64, by: Address, batchAmount: UInt32, interval: UFix64)

    /* --- Variable, Enums and Structs --- */
    access(all)
    let StakingAdminStoragePath: StoragePath
    access(all)
    let StakingAdminPublicPath: PublicPath
    access(all)
    let StakingControllerStoragePath: StoragePath

    /* --- Interfaces & Resources --- */

    /// Staking Admin Public Resource interface
    ///
    access(all) resource interface StakingAdminPublic {
        access(all)
        view fun isWhitelisted(address: Address): Bool
    }

    /// Staking Admin Resource, represents a staking admin and store in admin's account
    ///
    access(all) resource StakingAdmin: StakingAdminPublic {
        access(self)
        let whitelist: {Address: Bool}

        init() {
            self.whitelist = {}
        }

        access(all)
        view fun isWhitelisted(address: Address): Bool {
            return self.whitelist[address] ?? false
        }

        access(Admin)
        fun updateWhitelist(address: Address, isWhitelisted: Bool) {
            self.whitelist[address] = isWhitelisted

            emit StakingWhitelistUpdated(address: address, isWhitelisted: isWhitelisted)
        }
    }

    /// Staking Controller Resource, represents a staking controller
    ///
    access(all) resource StakingController {

        /// Returns the address of the controller
        ///
        access(all)
        view fun getControllerAddress(): Address {
            return self.owner?.address ?? panic("The controller is not stored in the account")
        }

        /// Create a new staking pool
        ///
        access(Manage)
        fun enableAndCreateFRC20Staking(
            tick: String,
            newAccount: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>,
        ){
            pre {
                FRC20StakingManager.isWhitelisted(self.getControllerAddress()): "The controller is not whitelisted"
            }

            // singleton resources
            let frc20Indexer = FRC20Indexer.getIndexer()
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()

            // Check if the token is already registered
            let tokenMeta = frc20Indexer.getTokenMeta(tick: tick.toLower()) ?? panic("The token is not registered")
            // no need to check if deployer is whitelisted, because the controller is whitelisted

            // create the account for the staking at the accounts pool
            acctsPool.setupNewChildForStaking(
                tick: tokenMeta.tick,
                newAccount
            )

            // ensure all market resources are available
            self.ensureStakingResourcesAvailable(tick: tokenMeta.tick)

            // emit the event
            emit StakingPoolEnabled(
                tick: tokenMeta.tick,
                address: acctsPool.getFRC20StakingAddress(tick: tokenMeta.tick) ?? panic("The staking account was not created"),
                by: self.getControllerAddress()
            )
        }

        /// Ensure all staking resources are available
        ///
        access(Manage)
        fun ensureStakingResourcesAvailable(tick: String) {
            pre {
                FRC20StakingManager.isWhitelisted(self.getControllerAddress()): "The controller is not whitelisted"
            }

            let isUpdated = FRC20StakingManager._ensureStakingResourcesAvailable(tick: tick)

            if isUpdated {
                // singleton resources
                let acctsPool = FRC20AccountsPool.borrowAccountsPool()

                emit StakingPoolResourcesUpdated(
                    tick: tick,
                    address: acctsPool.getFRC20StakingAddress(tick: tick) ?? panic("The staking account was not created"),
                    by: self.getControllerAddress()
                )
            }
        }

        /// Donate all shared pool FLOW tokens to the vesting pool
        ///
        access(Manage)
        fun donateAllSharedPoolFlowTokenToVesting(
            tick: String,
            childType: FRC20AccountsPool.ChildAccountType,
            vestingBatchAmount: UInt32,
            vestingInterval: UFix64,
        ) {
            pre {
                FRC20StakingManager.isWhitelisted(self.getControllerAddress()): "The controller is not whitelisted"
            }

            // singleton resources
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            // try to borrow the account to check if it was created
            let childAcctRef = acctsPool.borrowChildAccount(type: childType, nil)
                ?? panic("The shared pool account was not created")

            let flowVaultRef = childAcctRef.storage
                .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("The flow vault is not found")
            let storageUsageBalance = UFix64(childAcctRef.storage.used) / UFix64(childAcctRef.storage.capacity) * flowVaultRef.balance
            // Keep the 2x of the storage usage balance
            let availbleBalance = flowVaultRef.balance - storageUsageBalance * 2.0 - 0.01
            // ensure the flow balance is enough
            assert(
                availbleBalance > 0.0,
                message: "The flow balance is not enough"
            )

            // withdraw the flow tokens
            self._donateTokenToVesting(
                vault: <- flowVaultRef.withdraw(amount: availbleBalance),
                tick: tick,
                vestingBatchAmount: vestingBatchAmount,
                vestingInterval: vestingInterval
            )
        }

        /// Donate FLOW in the child account to the vesting pool
        ///
        access(Manage)
        fun donateFlowTokenToVesting(
            tick: String,
            amount: UFix64,
            vestingBatchAmount: UInt32,
            vestingInterval: UFix64,
        ) {
            pre {
                FRC20StakingManager.isWhitelisted(self.getControllerAddress()): "The controller is not whitelisted"
            }

            // singleton resources
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            // try to borrow the account to check if it was created
            let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.Staking, tick)
                ?? panic("The staking account was not created")

            let flowVaultRef = childAcctRef.storage
                .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("The flow vault is not found")
            let storageUsageBalance = UFix64(childAcctRef.storage.used) / UFix64(childAcctRef.storage.capacity) * flowVaultRef.balance
            // Keep the 2x of the storage usage balance
            let availbleBalance = flowVaultRef.balance - storageUsageBalance * 2.0 - 0.01
            // ensure the flow balance is enough
            assert(
                availbleBalance >= amount,
                message: "The flow balance is not enough"
            )

            // withdraw the flow tokens
            self._donateTokenToVesting(
                vault: <- flowVaultRef.withdraw(amount: amount),
                tick: tick,
                vestingBatchAmount: vestingBatchAmount,
                vestingInterval: vestingInterval
            )
        }

        /// Donate FLOW in the child account to the vesting pool
        ///
        access(self)
        fun _donateTokenToVesting(
            vault: @{FungibleToken.Vault},
            tick: String,
            vestingBatchAmount: UInt32,
            vestingInterval: UFix64,
        ) {
            let systemAddr = FRC20StakingManager.account.address
            // convert to change
            let changeToDonate <- FRC20FTShared.wrapFungibleVaultChange(
                ftVault: <- vault,
                from: systemAddr
            )
            // call the internal method to donate
            FRC20StakingManager.donateToVestingFromChange(
                changeToDonate: <- changeToDonate,
                tick: tick,
                vestingBatchAmount: vestingBatchAmount,
                vestingInterval: vestingInterval
            )
        }

        /// Register a reward strategy
        ///
        access(Manage)
        fun registerRewardStrategy(
            stakeTick: String,
            rewardTick: String,
        ) {
            // singleton resources
            let acctPool = FRC20AccountsPool.borrowAccountsPool()
            let frc20Indexer = FRC20Indexer.getIndexer()

            let poolAddr = acctPool.getFRC20StakingAddress(tick: stakeTick)
                ?? panic("The staking pool is not enabled")
            let pool = FRC20Staking.borrowPool(poolAddr)
                ?? panic("The staking pool is not found")

            // Check if the reward token is registered
            let isFlowFT = rewardTick == "" || CompositeType(rewardTick) != nil
            assert(
                isFlowFT || frc20Indexer.getTokenMeta(tick: rewardTick) != nil,
                message: "The reward token is not registered"
            )
            // Check if the reward strategy is already registered
            assert(
                pool.getRewardDetails(rewardTick) == nil,
                message: "The reward strategy is already registered"
            )
            assert(
                pool.tick == stakeTick,
                message: "The staking pool tick is not the same as the requested"
            )

            // Check if the controller is whitelisted or staked enough tokens
            let controlleAddr = self.getControllerAddress()
            assert(
                FRC20StakingManager.isEligibleForRegistering(stakeTick: stakeTick, addr: controlleAddr),
                message: "The controller is not whitelisted or staked enough tokens"
            )

            pool.registerRewardStrategy(rewardTick: rewardTick)

            emit StakingPoolRewardStrategyRegistered(
                tick: stakeTick,
                rewardTick: rewardTick,
                by: self.getControllerAddress()
            )
        }
    }

    /* --- Contract access methods  --- */

    access(contract)
    fun _ensureStakingResourcesAvailable(tick: String): Bool {
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.Staking, tick)
            ?? panic("The staking account was not created")

        var isUpdated = false
        // The staking pool should have the following resources in the account:
        // - FRC20Staking.Pool: Pool resource
        // - FRC20FTShared.SharedStore: Staking Pool configuration
        // - FRC20FTShared.Hooks: Hooks for the staking pool
        // - FixesHeartbeat.IHeartbeatHook: Register to FixesHeartbeat with the scope of "Staking:<tick>"
        // - FRC20StakingVesting.Vault: Vesting vault for the staking pool
        // - FRC20StakingForwarder.Forwarder: Forward $FLOW to the staking pool

        if let pool = childAcctRef.storage.borrow<&FRC20Staking.Pool>(from: FRC20Staking.StakingPoolStoragePath) {
            assert(
                pool.tick == tick,
                message: "The staking pool tick is not the same as the requested"
            )
        } else {
            // create the staking and save it in the account
            let pool <- FRC20Staking.createPool(tick)
            // save the staking in the account
            childAcctRef.storage.save(<- pool, to: FRC20Staking.StakingPoolStoragePath)
            // reference of stake pool
            let poolRef = childAcctRef.storage.borrow<&FRC20Staking.Pool>(from: FRC20Staking.StakingPoolStoragePath)
                ?? panic("The staking pool is not found")
            poolRef.initialize()

            // link the staking to the public path
            childAcctRef.capabilities.unpublish(FRC20Staking.StakingPoolPublicPath)
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&FRC20Staking.Pool>(FRC20Staking.StakingPoolStoragePath),
                at: FRC20Staking.StakingPoolPublicPath
            )

            isUpdated = true
        }

        // create the shared store and save it in the account
        if childAcctRef.storage.borrow<&AnyResource>(from: FRC20FTShared.SharedStoreStoragePath) == nil {
            let sharedStore <- FRC20FTShared.createSharedStore()
            childAcctRef.storage.save(<- sharedStore, to: FRC20FTShared.SharedStoreStoragePath)
            // link the shared store to the public path
            childAcctRef.capabilities.unpublish(FRC20FTShared.SharedStorePublicPath)
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&FRC20FTShared.SharedStore>(FRC20FTShared.SharedStoreStoragePath),
                at: FRC20FTShared.SharedStorePublicPath
            )

            isUpdated = true || isUpdated
        }

        // create the hooks and save it in the account
        if childAcctRef.storage.borrow<&AnyResource>(from: FRC20FTShared.TransactionHookStoragePath) == nil {
            let hooks <- FRC20FTShared.createHooks()
            childAcctRef.storage.save(<- hooks, to: FRC20FTShared.TransactionHookStoragePath)

            isUpdated = true || isUpdated
        }

        // link the hooks to the public path
        if childAcctRef
            .capabilities.get<&FRC20FTShared.Hooks>(FRC20FTShared.TransactionHookPublicPath)
            .borrow() == nil {
            // link the hooks to the public path
            childAcctRef.capabilities.unpublish(FRC20FTShared.TransactionHookPublicPath)
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&FRC20FTShared.Hooks>(FRC20FTShared.TransactionHookStoragePath),
                at: FRC20FTShared.TransactionHookPublicPath
            )

            isUpdated = true || isUpdated
        }

        // Register to FixesHeartbeat
        let heartbeatScope = "Staking:".concat(tick)
        if !FixesHeartbeat.hasHook(scope: heartbeatScope, hookAddr: childAcctRef.address) {
            FixesHeartbeat.addHook(
                scope: heartbeatScope,
                hookAddr: childAcctRef.address,
                hookPath: FRC20FTShared.TransactionHookPublicPath
            )

            isUpdated = true || isUpdated
        }

        // Add hooks to the shared hooks reference

        // borrow the hooks reference
        let hooksRef = childAcctRef.storage
            .borrow<auth(FRC20FTShared.Manage) &FRC20FTShared.Hooks>(from: FRC20FTShared.TransactionHookStoragePath)
            ?? panic("The hooks were not created")

        // --- Vesting ---

        if childAcctRef.storage.borrow<&AnyResource>(from: FRC20StakingVesting.storagePath) == nil {
            let vesting <- FRC20StakingVesting.createVestingVault()
            childAcctRef.storage.save(<- vesting, to: FRC20StakingVesting.storagePath)

            isUpdated = true || isUpdated
        }

        if childAcctRef
            .capabilities.get<&FRC20StakingVesting.Vault>(FRC20StakingVesting.publicPath)
            .borrow() == nil {
            // link the vesting to the public path
            childAcctRef.capabilities.unpublish(FRC20StakingVesting.publicPath)
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&FRC20StakingVesting.Vault>(FRC20StakingVesting.storagePath),
                at: FRC20StakingVesting.publicPath
            )

            isUpdated = true || isUpdated
        }

        // add vesting to hooks

        let vestingHookCap = childAcctRef
            .capabilities.get<&FRC20StakingVesting.Vault>(FRC20StakingVesting.publicPath)
        let vestingHookRef = vestingHookCap.borrow()
            ?? panic("Could not borrow the vesting hook reference")
        if !hooksRef.hasHook(vestingHookRef.getType()) {
            hooksRef.addHook(vestingHookCap)

            isUpdated = true || isUpdated
        }

        // --- Forwarder ---

        // This is the standard receiver path of FlowToken
        let flowReceiverPath = /public/flowTokenReceiver
        // check if the forwarder is already created
        if childAcctRef.storage.borrow<&AnyResource>(from: FRC20StakingForwarder.StakingForwarderStoragePath) == nil {
            let forwarder <- FRC20StakingForwarder.createNewForwarder(childAcctRef.address)
            childAcctRef.storage.save(<- forwarder, to: FRC20StakingForwarder.StakingForwarderStoragePath)

            // link public interface
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&FRC20StakingForwarder.Forwarder>(FRC20StakingForwarder.StakingForwarderStoragePath),
                at: FRC20StakingForwarder.StakingForwarderPublicPath
            )

            isUpdated = true || isUpdated
        }

         // Unlink the existing receiver capability for flowReceiverPath
        if childAcctRef.capabilities.get<&{FungibleToken.Receiver}>(flowReceiverPath).check() {
            // link the forwarder to the public path
            childAcctRef.capabilities.unpublish(flowReceiverPath)
            // Link the new forwarding receiver capability
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&{FungibleToken.Receiver}>(FRC20StakingForwarder.StakingForwarderStoragePath),
                at: flowReceiverPath
            )

            // link the FlowToken to the forwarder fallback path
            let fallbackPath = Fixes.getFallbackFlowTokenPublicPath()
            childAcctRef.capabilities.unpublish(fallbackPath)
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&FlowToken.Vault>(/storage/flowTokenVault),
                at: fallbackPath
            )

            isUpdated = true || isUpdated
        }
        return isUpdated
    }

    /** ---- Public Methods - Controller ---- */

    /// Check if the given address is whitelisted
    ///
    access(all)
    view fun isWhitelisted(_ address: Address): Bool {
        if address == self.account.address {
            return true
        }
        let admin = self.account
            .capabilities.get<&StakingAdmin>(self.StakingAdminPublicPath)
            .borrow()
            ?? panic("Could not borrow the admin reference")
        return admin.isWhitelisted(address: address)
    }

    /// Check if the given address is eligible for registering
    ///
    access(all)
    view fun isEligibleForRegistering(stakeTick: String, addr: Address): Bool {
        // singleton resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        // Get the staking pool address
        let poolAddress = acctsPool.getFRC20StakingAddress(tick: stakeTick)
            ?? panic("The staking pool is not enabled")
        // borrow the staking pool
        let pool = FRC20Staking.borrowPool(poolAddress)
            ?? panic("The staking pool is not found")
        let totalStakedBalance = pool.getDetails().totalStaked
                // if the controller staked more than 10% of the total staked tokens, then it is valid
        return self.isEligibleByStakePower(stakeTick: stakeTick, addr: addr, threshold: totalStakedBalance * 0.1)
    }

    /// Check if the given address is eligible by stake power
    ///
    access(all)
    view fun isEligibleByStakePower(stakeTick: String, addr: Address, threshold: UFix64): Bool {
        // Check if the controller is whitelisted or staked enough tokens
        var isValid = self.isWhitelisted(addr)
        // Check if the controller is staked enough tokens
        if !isValid {
            if let delegator = FRC20Staking.borrowDelegator(addr) {
                let controllerStakedBalance = delegator.getStakedBalance(tick: stakeTick)
                // if the controller staked more than 10% of the total staked tokens, then it is valid
                isValid = controllerStakedBalance >= threshold
            }
        }
        return isValid
    }

    /// Create a new staking controller
    ///
    access(all)
    fun createController(): @StakingController {
        return <- create StakingController()
    }

    /** ---- Public Methods - User ---- */

    /// Borrow the platform staking pool.
    ///
    access(all)
    view fun borrowPlatformStakingPool(): &FRC20Staking.Pool {
        // singleton resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        // Get the staking pool address
        let stakeTick = FRC20FTShared.getPlatformStakingTickerName()
        let poolAddress = acctsPool.getFRC20StakingAddress(tick: stakeTick)
            ?? panic("The staking pool is not enabled")
        // borrow the staking pool
        return FRC20Staking.borrowPool(poolAddress) ?? panic("The staking pool is not found")
    }

    /// Stake tokens
    ///
    access(all)
    fun stake(ins: auth(Fixes.Extractable) &Fixes.Inscription) {
        // singleton resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
        let op = meta["op"]?.toLower() ?? panic("The token operation is not found")
        assert(
            op == "withdraw",
            message: "The token operation should be withdraw."
        )
        let usage = meta["usage"]?.toLower() ?? panic("The token usage is not found")
        assert(
            usage == "staking",
            message: "The token usage should be staking."
        )

        let fromAddr = ins.owner?.address ?? panic("The inscription owner is not found")
        assert(
            FRC20Staking.borrowDelegator(fromAddr) != nil,
            message: "The inscription owner is not a delegator"
        )

        let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")

        /// Check if the staking is already enabled
        let stakingAddress = acctsPool.getFRC20StakingAddress(tick: tick)
            ?? panic("The staking pool is not enabled")
        let stakingPool = FRC20Staking.borrowPool(stakingAddress)
            ?? panic("The staking pool is not found")
        /// Withdraw the frc20 tokens, will validate the inscription
        let changeToStake <- frc20Indexer.withdrawChange(ins: ins)
        /// Stake the tokens
        stakingPool.stake(<- changeToStake)
    }

    /// Unstake tokens
    ///
    access(all)
    fun unstake(
        _ semiNFTColCap: Capability<auth(NonFungibleToken.Update, NonFungibleToken.Withdraw) &FRC20SemiNFT.Collection>,
        nftId: UInt64
    ) {
        pre {
            semiNFTColCap.check(): "The semiNFT collection is not valid"
        }
        let semiNFTCol = semiNFTColCap.borrow()
            ?? panic("Could not borrow the semiNFT collection")
        let nft = semiNFTCol.borrowFRC20SemiNFT(id: nftId)
            ?? panic("The semiNFT is not found")
        let poolAddress = nft.getFromAddress()

        // singleton resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        let stakingPool = FRC20Staking.borrowPool(poolAddress)
            ?? panic("The staking pool is not found")
        /// Unstake the tokens
        stakingPool.unstake(semiNFTCol, nftId: nftId)
    }

    /// Claim all unlocked unstaking changes
    ///
    access(all)
    fun claimUnlockedUnstakingChange(
        ins: auth(Fixes.Extractable) &Fixes.Inscription
    ) {
        pre {
            ins.isExtractable(): "The inscription is not extractable"
        }
        // singleton resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        assert(
            frc20Indexer.isValidFRC20Inscription(ins: ins),
            message: "The inscription is not a valid FRC20 inscription"
        )

        // inscription data
        let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
        let op = meta["op"]?.toLower() ?? panic("The token operation is not found")
        assert(
            op == "deposit",
            message: "The token operation should be deposit."
        )

        let fromAddr = ins.owner?.address ?? panic("The inscription owner is not found")
        assert(
            FRC20Staking.borrowDelegator(fromAddr) != nil,
            message: "The inscription owner is not a delegator"
        )

        let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")
        let poolAddress = acctsPool.getFRC20StakingAddress(tick: tick)
            ?? panic("The staking pool is not enabled")
        let stakingPool = FRC20Staking.borrowPool(poolAddress)
            ?? panic("The staking pool is not found")
        if let unstakedChange <- stakingPool.claimUnlockedUnstakingChange(delegator: fromAddr) {
            // deposit the unstaked change
            frc20Indexer.depositChange(ins: ins, change: <- unstakedChange)
        } else {
            panic("No any unlocked staked FRC20 tokens can be claimed.")
        }
    }

    /// Donate FRC20 to the staking pool
    ///
    access(all)
    fun donateToStakingPool(
        tick: String,
        ins: auth(Fixes.Extractable) &Fixes.Inscription
    ) {
        // singleton resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        /// Check if the staking is already enabled
        let stakingAddress = acctsPool.getFRC20StakingAddress(tick: tick)
            ?? panic("The staking pool is not enabled")
        let stakingPool = FRC20Staking.borrowPool(stakingAddress)
            ?? panic("The staking pool is not found")

        let changeToDonate <- self._withdrawDonateChange(tick: tick, ins: ins)

        let rewardTick = changeToDonate.getOriginalTick()
        let rewardStrategy = stakingPool.borrowRewardStrategy(rewardTick)
            ?? panic("The reward strategy is not registered")

        let amountToDonate = changeToDonate.getBalance()
        assert(
            amountToDonate > 0.0,
            message: "The amount to donate should be greater than zero"
        )
        // Donate the tokens
        rewardStrategy.addIncome(income: <- changeToDonate)

        // emit the event
        emit StakingPoolDonated(
            tick: tick,
            rewardTick: rewardTick,
            amount: amountToDonate,
            by: ins.owner?.address ?? panic("The inscription owner is not found")
        )
    }

    /// Donate FRC20 to the vesting reward pool
    ///
    access(all)
    fun donateToVesting(
        tick: String,
        ins: auth(Fixes.Extractable) &Fixes.Inscription,
        vestingBatchAmount: UInt32,
        vestingInterval: UFix64,
    ) {
        // call the internal method
        self.donateToVestingFromChange(
            changeToDonate: <- self._withdrawDonateChange(tick: tick, ins: ins),
            tick: tick,
            vestingBatchAmount: vestingBatchAmount,
            vestingInterval: vestingInterval
        )
    }

    /// Donate Change to the staking's vesting pool
    /// (Internal Method)
    ///
    access(account)
    fun donateToVestingFromChange(
        changeToDonate: @FRC20FTShared.Change,
        tick: String,
        vestingBatchAmount: UInt32,
        vestingInterval: UFix64,
    ) {
        // singleton resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        let stakingAddress = acctsPool.getFRC20StakingAddress(tick: tick) ?? panic("The staking pool is not enabled")
        let vestingVault = FRC20StakingVesting.borrowVaultRef(stakingAddress)
            ?? panic("The vesting vault is not found")

        let rewardTick = changeToDonate.getOriginalTick()
        let amountToDonate = changeToDonate.getBalance()
        let fromAddr = changeToDonate.from
        assert(
            amountToDonate > 0.0,
            message: "The amount to donate should be greater than zero"
        )

        // Donate the tokens to the vesting vault
        vestingVault.addVesting(
            stakeTick: tick,
            rewardChange: <- changeToDonate,
            vestingBatchAmount: vestingBatchAmount,
            vestingInterval: vestingInterval
        )

        emit StakingPoolDonatedAsVesting(
            tick: tick,
            rewardTick: rewardTick,
            amount: amountToDonate,
            by: fromAddr,
            batchAmount: vestingBatchAmount,
            interval: vestingInterval
        )
    }

    /// Withdraw the donate change from FRC20 Indexer
    /// (Internal Method)
    ///
    access(contract)
    fun _withdrawDonateChange(
        tick: String,
        ins: auth(Fixes.Extractable) &Fixes.Inscription,
    ): @FRC20FTShared.Change {
        // singleton resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        /// Check if the staking is already enabled
        let stakingAddress = acctsPool.getFRC20StakingAddress(tick: tick)
            ?? panic("The staking pool is not enabled")
        let stakingPool = FRC20Staking.borrowPool(stakingAddress)
            ?? panic("The staking pool is not found")

        // inscription data
        let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
        let op = meta["op"]?.toLower() ?? panic("The token operation is not found")
        assert(
            op == "withdraw",
            message: "The token operation should be withdraw."
        )
        let usage = meta["usage"]?.toLower() ?? panic("The token usage is not found")
        assert(
            usage == "donate",
            message: "The token usage should be donate."
        )

        let fromAddr = ins.owner?.address ?? panic("The inscription owner is not found")
        let insTick = meta["tick"]?.toLower()

        var rewardStrategy: &FRC20Staking.RewardStrategy? = nil
        if insTick == nil || insTick == "" {
            rewardStrategy = stakingPool.borrowRewardStrategy("")
        } else {
            rewardStrategy = stakingPool.borrowRewardStrategy(insTick!)
        }
        // Check if the reward strategy is registered
        assert(
            rewardStrategy != nil,
            message: "The reward strategy is not registered"
        )
        // the final reward tick
        let rewardTick = rewardStrategy!.rewardTick

        // Withdraw the frc20 tokens, will validate the inscription
        var changeToDonate: @FRC20FTShared.Change? <- nil
        if rewardTick == "" {
            changeToDonate <-! frc20Indexer.extractFlowVaultChangeFromInscription(
                ins,
                amount: ins.getInscriptionValue() - ins.getMinCost()
            )
            // extract the FLOW tokens
            frc20Indexer.returnChange(change: <- FRC20FTShared.wrapFungibleVaultChange(
                ftVault: <- ins.extract(),
                from: ins.owner?.address ?? panic("The inscription owner is not found")
            ))
        } else {
            changeToDonate <-! frc20Indexer.withdrawChange(ins: ins)
        }
        return <- (changeToDonate ?? panic("The change to donate is not found"))
    }

    /// Claim rewards
    ///
    access(all)
    fun claimRewards(
        _ semiNFTColRef: auth(NonFungibleToken.Update) &FRC20SemiNFT.Collection,
        nftIds: [UInt64]
    ) {
        // singleton resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        let ownerAddr = semiNFTColRef.owner?.address
            ?? panic("The semiNFT collection owner is not found")

        // loop through all nftIds
        for nftId in nftIds {
            let nft = semiNFTColRef.borrowFRC20SemiNFT(id: nftId)
                ?? panic("The semiNFT is not found")
            let poolAddress = nft.getFromAddress()

            // borrow the staking pool
            let stakingPool = FRC20Staking.borrowPool(poolAddress)
                ?? panic("The staking pool is not found")

            // get the reward ticks
            let rewardTicks = stakingPool.getRewardNames()
            // loop through all reward ticks
            for rewardTick in rewardTicks {
                // get the reward strategy
                let rewardStrategy = stakingPool.borrowRewardStrategy(rewardTick)
                    ?? panic("The reward strategy is not registered")
                // claim the reward, the from should be same as the nft owner
                let rewardChange <- rewardStrategy.claim(byNft: nft)
                if rewardChange.getBalance() > 0.0 {
                    // The reward is not empty, return the change to the user
                    frc20Indexer.returnChange(change: <- rewardChange)
                } else {
                    Burner.burn(<- rewardChange)
                }
            } // end reward Ticks
        } // end nftIds
    }

    /// init method
    init() {
        let identifier = "FRC20Staking_".concat(self.account.address.toString())
        self.StakingAdminStoragePath = StoragePath(identifier: identifier.concat("_admin"))!
        self.StakingAdminPublicPath = PublicPath(identifier: identifier.concat("_admin"))!
        self.StakingControllerStoragePath = StoragePath(identifier: identifier.concat("_controller"))!

        // create the admin account
        let admin <- create StakingAdmin()
        self.account.storage.save(<-admin, to: self.StakingAdminStoragePath)
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&StakingAdmin>(self.StakingAdminStoragePath),
            at: self.StakingAdminPublicPath
        )

        // create the controller
        let controller <- create StakingController()
        self.account.storage.save(<-controller, to: self.StakingControllerStoragePath)

        emit ContractInitialized()
    }
}
