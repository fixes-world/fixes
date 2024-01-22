/**
#
# Author: FIXeS World <https://fixes.world/>
#
*/
// Third Party Imports
import "FungibleToken"
import "FlowToken"
import "NonFungibleToken"
import "MetadataViews"
// Fixes Imports
import "Fixes"
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20Staking"
import "FRC20SemiNFT"

access(all) contract FRC20StakingManager {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()
    /// Event emitted when the whitelist is updated
    access(all) event StakingWhitelistUpdated(address: Address, isWhitelisted: Bool)
    /// Event emitted when a staking pool is enabled
    access(all) event StakingPoolEnabled(tick: String, address: Address, by: Address)
    /// Event emitted when a staking pool resources are updated
    access(all) event StakingPoolResourcesUpdated(tick: String, address: Address, by: Address)

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
        access(all) fun isWhitelisted(address: Address): Bool
    }

    /// Staking Admin Resource, represents a staking admin and store in admin's account
    ///
    access(all) resource StakingAdmin: StakingAdminPublic {
        access(all)
        let whitelist: {Address: Bool}

        init() {
            self.whitelist = {}
        }

        access(all) view
        fun isWhitelisted(address: Address): Bool {
            return self.whitelist[address] ?? false
        }

        access(all)
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
        fun getControllerAddress(): Address {
            return self.owner?.address ?? panic("The controller is not stored in the account")
        }

        /// Create a new staking pool
        ///
        access(all)
        fun enableAndCreateFRC20Staking(
            tick: String,
            newAccount: Capability<&AuthAccount>,
        ){
            pre {
                FRC20StakingManager.isWhitelisted(self.getControllerAddress()): "The controller is not whitelisted"
            }

            // singletoken resources
            let frc20Indexer = FRC20Indexer.getIndexer()
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()

            // Check if the token is already registered
            let tokenMeta = frc20Indexer.getTokenMeta(tick: tick.toLower()) ?? panic("The token is not registered")
            // no need to check if deployer is whitelisted, because the controller is whitelisted

            // create the account for the market at the accounts pool
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
        access(all)
        fun ensureStakingResourcesAvailable(tick: String) {
            pre {
                FRC20StakingManager.isWhitelisted(self.getControllerAddress()): "The controller is not whitelisted"
            }

            let isUpdated = FRC20StakingManager._ensureStakingResourcesAvailable(tick: tick)

            if isUpdated {
                // singletoken resources
                let acctsPool = FRC20AccountsPool.borrowAccountsPool()

                emit StakingPoolResourcesUpdated(
                    tick: tick,
                    address: acctsPool.getFRC20StakingAddress(tick: tick) ?? panic("The staking account was not created"),
                    by: self.getControllerAddress()
                )
            }
        }
    }

    /* --- Contract access methods  --- */

    access(contract)
    fun _ensureStakingResourcesAvailable(tick: String): Bool {
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.Staking, tick: tick)
            ?? panic("The market account was not created")

        var isUpdated = false
        // The staking pool should have the following resources in the account:
        // - FRC20Staking.Pool: Pool resource
        // - FRC20FTShared.SharedStore: Staking Pool configuration
        // - FRC20FTShared.Hooks: Hooks for the staking pool

        if let pool = childAcctRef.borrow<&FRC20Staking.Pool>(from: FRC20Staking.StakingPoolStoragePath) {
            assert(
                pool.tick == tick,
                message: "The staking pool tick is not the same as the requested"
            )
        } else {
            // create the market and save it in the account
            let pool <- FRC20Staking.createPool(tick)
            // save the market in the account
            childAcctRef.save(<- pool, to: FRC20Staking.StakingPoolStoragePath)
            // link the market to the public path
            childAcctRef.unlink(FRC20Staking.StakingPoolPublicPath)
            childAcctRef.link<&FRC20Staking.Pool{FRC20Staking.PoolPublic}>(FRC20Staking.StakingPoolPublicPath, target: FRC20Staking.StakingPoolStoragePath)

            isUpdated = true
        }

        // create the shared store and save it in the account
        if childAcctRef.borrow<&AnyResource>(from: FRC20FTShared.SharedStoreStoragePath) == nil {
            let sharedStore <- FRC20FTShared.createSharedStore()
            childAcctRef.save(<- sharedStore, to: FRC20FTShared.SharedStoreStoragePath)
            // link the shared store to the public path
            childAcctRef.unlink(FRC20FTShared.SharedStorePublicPath)
            childAcctRef.link<&FRC20FTShared.SharedStore{FRC20FTShared.SharedStorePublic}>(FRC20FTShared.SharedStorePublicPath, target: FRC20FTShared.SharedStoreStoragePath)

            isUpdated = true || isUpdated
        }

        // create the hooks and save it in the account
        if childAcctRef.borrow<&AnyResource>(from: FRC20FTShared.TransactionHookStoragePath) == nil {
            let hooks <- FRC20FTShared.createHooks()
            childAcctRef.save(<- hooks, to: FRC20FTShared.TransactionHookStoragePath)
            // link the hooks to the public path
            childAcctRef.unlink(FRC20FTShared.TransactionHookPublicPath)
            childAcctRef.link<&FRC20FTShared.Hooks{FRC20FTShared.TransactionHook}>(FRC20FTShared.TransactionHookPublicPath, target: FRC20FTShared.TransactionHookStoragePath)

            isUpdated = true || isUpdated
        }

        // TODO: Add more hooks

        return isUpdated
    }

    /** ---- Public Methods - Controller ---- */

    /// Check if the given address is whitelisted
    ///
    access(all) view
    fun isWhitelisted(_ address: Address): Bool {
        if address == self.account.address {
            return true
        }
        let admin = self.account
            .getCapability<&StakingAdmin{StakingAdminPublic}>(self.StakingAdminPublicPath)
            .borrow()
            ?? panic("Could not borrow the admin reference")
        return admin.isWhitelisted(address: address)
    }

    /// Create a new staking controller
    ///
    access(all)
    fun createController(): @StakingController {
        return <- create StakingController()
    }

    /** ---- Public Methods - User ---- */

    /// Stake tokens
    ///
    access(all)
    fun stake(ins: &Fixes.Inscription) {
        // singletoken resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = frc20Indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
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
        /// Withdraw the tokens, will validate the inscription
        let changeToStake <- frc20Indexer.withdrawChange(ins: ins)
        /// Stake the tokens
        stakingPool.stake(<- changeToStake)
    }

    /// Unstake tokens
    ///
    fun unstake(
        _ semiNFTColCap: Capability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>,
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

        // singletoken resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        let stakingPool = FRC20Staking.borrowPool(poolAddress)
            ?? panic("The staking pool is not found")
        /// Unstake the tokens
        stakingPool.unstake(semiNFTCol, nftId: nftId)
    }

    /// Claim all unlocked unstaking changes
    ///
    fun claimUnlockedUnstakingChange(
        ins: &Fixes.Inscription
    ) {
        pre {
            ins.isExtractable(): "The inscription is not extractable"
        }
        // singletoken resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        assert(
            frc20Indexer.isValidFRC20Inscription(ins: ins),
            message: "The inscription is not a valid FRC20 inscription"
        )

        // inscription data
        let meta = frc20Indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
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

    /// init method
    init() {
        let identifier = "FRC20Staking_".concat(self.account.address.toString())
        self.StakingAdminStoragePath = StoragePath(identifier: identifier.concat("_admin"))!
        self.StakingAdminPublicPath = PublicPath(identifier: identifier.concat("_admin"))!
        self.StakingControllerStoragePath = StoragePath(identifier: identifier.concat("_controller"))!

        // create the admin account
        let admin <- create StakingAdmin()
        self.account.save(<-admin, to: self.StakingAdminStoragePath)
        self.account.link<&StakingAdmin{StakingAdminPublic}>(self.StakingAdminPublicPath, target: self.StakingAdminStoragePath)

        // create the controller
        let controller <- create StakingController()
        self.account.save(<-controller, to: self.StakingControllerStoragePath)

        emit ContractInitialized()
    }
}
