// Third-party imports
import "MetadataViews"
import "FungibleToken"
import "FungibleTokenMetadataViews"
import "FlowToken"
import "HybridCustody"
// Fixes imports
// import "Fixes"
// import "FRC20FTShared"
import "FRC20Indexer"

pub contract FRC20AccountsPool {

    /* --- Events --- */
    /// Event emitted when the contract is initialized
    pub event ContractInitialized()
    /// Event emitted when a new child account is added, if tick is nil, it means the child account is not a shared account
    pub event NewChildAccountAdded(type: UInt8, address: Address, tick: String?)

    /* --- Variable, Enums and Structs --- */

    access(all)
    let AccountsPoolStoragePath: StoragePath
    access(all)
    let AccountsPoolPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    pub enum ChildAccountType: UInt8 {
        pub case Market
        pub case Staking
    }

    /// The public interface can be accessed by anyone
    ///
    pub resource interface PoolPublic {
        /// ---- Getters ----
        /// Returns the address of the FRC20 staking for the given tick
        access(all) view
        fun getFRC20StakingAddress(tick: String): Address?
        /// Returns the address of the FRC20 market for the given tick
        access(all) view
        fun getFRC20MarketAddress(tick: String): Address?
        /// Returns the address of the FRC20 market for the given tick
        access(all) view
        fun getMarketSharedAddress(): Address?
        /// Returns the addresses of the FRC20 with the given type
        access(all) view
        fun getFRC20Addresses(type: ChildAccountType): {String: Address}
        /// Returns the flow token receiver for the given tick
        access(all)
        fun borrowFRC20MarketFlowTokenReceiver(tick: String): &FlowToken.Vault{FungibleToken.Receiver}?
        /// Returns the flow token receiver for the given tick
        access(all)
        fun borrowFRC20StakingFlowTokenReceiver(tick: String): &FlowToken.Vault{FungibleToken.Receiver}?
        /// Returns the address of the FRC20 market for the given tick
        access(all)
        fun borrowMarketSharedFlowTokenReceiver(): &FlowToken.Vault{FungibleToken.Receiver}?
        /// ----- Access account methods -----
        /// Borrow child's AuthAccount
        access(account)
        fun borrowChildAccount(type: ChildAccountType, tick: String?): &AuthAccount?
        /// Sets up a new child account
        access(account)
        fun setupNewChildForTick(type: ChildAccountType, tick: String, _ acctCap: Capability<&AuthAccount>)
    }

    /// The admin interface can only be accessed by the the account manager's owner
    ///
    pub resource interface PoolAdmin {
        /// Sets up a new child account
        access(all)
        fun setupNewChildForShared(
            type: ChildAccountType,
            _ acctCap: Capability<&AuthAccount>,
        )
    }

    pub resource Pool: PoolPublic, PoolAdmin {
        access(self)
        let hcManagerCap: Capability<&HybridCustody.Manager{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>
        // AccountType -> Tick -> Address
        access(self)
        let tickAddressMapping: {ChildAccountType: {String: Address}}
        // AccountType -> Address
        access(self)
        let sharedAddressMappping: {ChildAccountType: Address}

        init(
            _ hcManagerCap: Capability<&HybridCustody.Manager{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>
        ) {
            self.hcManagerCap = hcManagerCap
            self.tickAddressMapping = {}
            self.sharedAddressMappping = {}
        }

        /** ---- Public Methods ---- */

        /// Returns the address of the FRC20 market for the given tick
        access(all) view
        fun getFRC20MarketAddress(tick: String): Address? {
            if let tickDict = self.borrowTickDict(type: ChildAccountType.Market) {
                return tickDict[tick]
            }
            return nil
        }

        /// Returns the address of the FRC20 staking for the given tick
        access(all) view
        fun getFRC20StakingAddress(tick: String): Address? {
            if let tickDict = self.borrowTickDict(type: ChildAccountType.Staking) {
                return tickDict[tick]
            }
            return nil
        }

        /// Returns the address of the FRC20 market for the given tick
        access(all) view
        fun getMarketSharedAddress(): Address? {
            return self.sharedAddressMappping[ChildAccountType.Market]
        }

        /// Returns the addresses of the FRC20 with the given type
        access(all) view
        fun getFRC20Addresses(type: ChildAccountType): {String: Address} {
            if let tickDict = self.tickAddressMapping[type] {
                return tickDict
            }
            return {}
        }

        /// Returns the flow token receiver for the given tick
        access(all)
        fun borrowFRC20MarketFlowTokenReceiver(tick: String): &FlowToken.Vault{FungibleToken.Receiver}? {
            if let addr = self.getFRC20MarketAddress(tick: tick) {
                return FRC20Indexer.borrowFlowTokenReceiver(addr)
            }
            return nil
        }

        /// Returns the flow token receiver for the given tick
        access(all)
        fun borrowFRC20StakingFlowTokenReceiver(tick: String): &FlowToken.Vault{FungibleToken.Receiver}? {
            if let addr = self.getFRC20StakingAddress(tick: tick) {
                return FRC20Indexer.borrowFlowTokenReceiver(addr)
            }
            return nil
        }

        /// Returns the address of the FRC20 market for the given tick
        access(all)
        fun borrowMarketSharedFlowTokenReceiver(): &FlowToken.Vault{FungibleToken.Receiver}? {
            if let addr = self.getMarketSharedAddress() {
                return FRC20Indexer.borrowFlowTokenReceiver(addr)
            }
            return nil
        }

        /// ----- Access account methods -----
        /// Borrow child's AuthAccount
        ///
        access(account)
        fun borrowChildAccount(type: ChildAccountType, tick: String?): &AuthAccount? {
            let hcManagerRef = self.hcManagerCap.borrow()
                ?? panic("Failed to borrow hcManager")
            if let tickSpecified = tick {
                let tickDict = self.borrowTickDict(type: type)
                if tickDict == nil {
                    return nil
                }
                if let childAddr = tickDict![tickSpecified] {
                    if let ownedChild = hcManagerRef.borrowOwnedAccount(addr: childAddr) {
                        return ownedChild.borrowAccount()
                    }
                }
            } else {
                if let sharedAddr = self.sharedAddressMappping[type] {
                    if let ownedChild = hcManagerRef.borrowOwnedAccount(addr: sharedAddr) {
                        return ownedChild.borrowAccount()
                    }
                }
            }
            return nil
        }

        /// Sets up a new child account
        ///
        access(account)
        fun setupNewChildForTick(
            type: ChildAccountType,
            tick: String,
            _ childAcctCap: Capability<&AuthAccount>,
        ) {
            pre {
                childAcctCap.check(): "Child account capability is invalid"
            }
            self._ensureTypeDictExists(type)

            let tickDict = self.borrowTickDict(type: type) ?? panic("Failed to borrow tick dict")
            assert(
                tickDict[tick] == nil,
                message: "Child account already exists"
            )

            let frc20Indexer = FRC20Indexer.getIndexer()
            // ensure token meta exists
            let tokenMeta = frc20Indexer.getTokenMeta(tick: tick)
            assert(
                tokenMeta != nil,
                message: "Token meta does not exist"
            )

            // record new child account address
            tickDict[tick] = childAcctCap.address

            // setup new child account
            self._setupChildAccount(childAcctCap)

            // emit event
            emit NewChildAccountAdded(
                type: type.rawValue,
                address: childAcctCap.address,
                tick: tick,
            )
        }

        /** ---- Admin Methods ---- */

        /// Sets up a new shared child account
        ///
        access(all)
        fun setupNewChildForShared(
            type: ChildAccountType,
            _ childAcctCap: Capability<&AuthAccount>,
        ) {
            pre {
                childAcctCap.check(): "Child account capability is invalid"
                self.sharedAddressMappping[type] == nil: "Shared child account already exists"
            }

            self.sharedAddressMappping[type] = childAcctCap.address

            // setup new child account
            self._setupChildAccount(childAcctCap)

            // emit event
            emit NewChildAccountAdded(
                type: type.rawValue,
                address: childAcctCap.address,
                tick: nil,
            )
        }

        /** ---- Internal Methods ---- */

        /// Sets up a new child account
        ///
        access(self)
        fun _setupChildAccount(
            _ childAcctCap: Capability<&AuthAccount>,
        ) {

            let hcManager = self.hcManagerCap.borrow() ?? panic("Failed to borrow hcManager")
            let hcManagerAddr = self.hcManagerCap.address

            // >>> [0] Get child AuthAccount
            let child = childAcctCap.borrow()
                ?? panic("Failed to borrow child account")

            // >>> [1] Child: createOwnedAccount
            if child.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath) == nil {
                let ownedAccount <- HybridCustody.createOwnedAccount(acct: childAcctCap)
                child.save(<-ownedAccount, to: HybridCustody.OwnedAccountStoragePath)
            }

            // ensure owned account exists
            assert(
                child.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath) != nil,
                message: "owned account not found"
            )

            // check that paths are all configured properly
            // public path
            child.unlink(HybridCustody.OwnedAccountPublicPath)
            child.link<&HybridCustody.OwnedAccount{HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(HybridCustody.OwnedAccountPublicPath, target: HybridCustody.OwnedAccountStoragePath)
            // private path(will deperated in the future)
            child.unlink(HybridCustody.OwnedAccountPrivatePath)
            child.link<&HybridCustody.OwnedAccount{HybridCustody.BorrowableAccount, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(HybridCustody.OwnedAccountPrivatePath, target: HybridCustody.OwnedAccountStoragePath)

            // >> [2] manager: add owned child account
            // Link a Capability for the new owner, retrieve & publish
            let ownenPrivCapPath = PrivatePath(identifier: HybridCustody.getOwnerIdentifier(hcManagerAddr))!
            child.unlink(ownenPrivCapPath)
            let ownedPrivCap = child
                .link<&{HybridCustody.OwnedAccountPrivate, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(
                    ownenPrivCapPath,
                    target: HybridCustody.OwnedAccountStoragePath
                ) ?? panic("failed to link child account capability")
            // add owned account to manager
            hcManager.addOwnedAccount(cap: ownedPrivCap)
        }

        /// Borrow tick dict
        ///
        access(self)
        fun borrowTickDict(type: ChildAccountType): &{String: Address}? {
            return &self.tickAddressMapping[type] as &{String: Address}?
        }

        /// ensure type dict exists
        ///
        access(self)
        fun _ensureTypeDictExists(_ type: ChildAccountType) {
            if self.tickAddressMapping[type] == nil {
                self.tickAddressMapping[type] = {}
            }
        }
    }

    /* --- Public Methods --- */

    /// Returns the public account manager interface
    ///
    access(all)
    fun borrowAccountsPool(): &Pool{PoolPublic} {
        return self.account
            .getCapability<&Pool{PoolPublic}>(self.AccountsPoolPublicPath)
            .borrow()
            ?? panic("Could not borrow accounts pool reference")
    }

    init() {
        let identifier = "FRC20AccountsPool_".concat(self.account.address.toString())
        self.AccountsPoolStoragePath = StoragePath(identifier: identifier)!
        self.AccountsPoolPublicPath = PublicPath(identifier: identifier)!

        // create account manager with hybrid custody manager capability
        if self.account.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) == nil {
            let m <- HybridCustody.createManager(filter: nil)
            self.account.save(<- m, to: HybridCustody.ManagerStoragePath)
        }

        // reset account manager paths
        self.account.unlink(HybridCustody.ManagerPublicPath)
        self.account.link<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(HybridCustody.ManagerPublicPath, target: HybridCustody.ManagerStoragePath)

        self.account.unlink(HybridCustody.ManagerPrivatePath)
        let cap = self.account
            .link<&HybridCustody.Manager{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>(
                HybridCustody.ManagerPrivatePath,
                target: HybridCustody.ManagerStoragePath
            )
            ?? panic("failed to link account manager capability")

        // init account manager
        let acctPool <- create Pool(cap)
        self.account.save(<- acctPool, to: self.AccountsPoolStoragePath)
        // link public capability
        self.account.link<&Pool{PoolPublic}>(self.AccountsPoolPublicPath, target: self.AccountsPoolStoragePath)

        emit ContractInitialized()
    }
}
