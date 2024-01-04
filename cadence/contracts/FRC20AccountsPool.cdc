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
    /// Event emitted when a new child account is added
    pub event NewChildAccountAdded(type: UInt8, tick: String, address: Address)

    /* --- Variable, Enums and Structs --- */
    pub let AccountsPoolStoragePath: StoragePath
    pub let AccountsPoolPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    pub enum ChildAccountType: UInt8 {
        pub case Market
        pub case Staking
    }

    /// The public interface can be accessed by anyone
    ///
    pub resource interface ManagerPublic {
        /// ---- Getters ----
        /// Returns the address of the FRC20 market for the given tick
        access(all) view
        fun getFRC20MarketAddress(tick: String): Address?
        /// Returns the address of the FRC20 staking for the given tick
        access(all) view
        fun getFRC20StakingAddress(tick: String): Address?
        /// Returns the flow token receiver for the given tick
        access(all)
        fun borrowFRC20MarketFlowTokenReceiver(tick: String): &FlowToken.Vault{FungibleToken.Receiver}?
        /// Returns the flow token receiver for the given tick
        access(all)
        fun borrowFRC20StakingFlowTokenReceiver(tick: String): &FlowToken.Vault{FungibleToken.Receiver}?
        /// ----- Access account methods -----
    }

    /// The admin interface can only be accessed by the the account manager's owner
    ///
    pub resource interface ManagerAdmin {
        /// Sets up a new child account
        access(all)
        fun setupNewChild(
            type: ChildAccountType,
            tick: String,
            _ acctCap: Capability<&AuthAccount>,
        )
    }

    pub resource AccountManager: ManagerPublic, ManagerAdmin {
        access(self)
        let hcManagerCap: Capability<&HybridCustody.Manager{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>
        access(self)
        let addressMapping: {ChildAccountType: {String: Address}}

        init(
            _ hcManagerCap: Capability<&HybridCustody.Manager{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>
        ) {
            self.hcManagerCap = hcManagerCap
            self.addressMapping = {}
        }

        /** ---- Public Methods ---- */

        /// Returns the address of the FRC20 market for the given tick
        access(all) view
        fun getFRC20MarketAddress(tick: String): Address? {
            let tickDict = self.borrowTickDict(type: ChildAccountType.Market)
            return tickDict[tick]
        }

        /// Returns the address of the FRC20 staking for the given tick
        access(all) view
        fun getFRC20StakingAddress(tick: String): Address? {
            let tickDict = self.borrowTickDict(type: ChildAccountType.Staking)
            return tickDict[tick]
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

        /** ---- Admin Methods ---- */

        /// Sets up a new child account
        ///
        access(all)
        fun setupNewChild(
            type: ChildAccountType,
            tick: String,
            _ childAcctCap: Capability<&AuthAccount>,
        ) {
            pre {
                childAcctCap.check(): "Child account capability is invalid"
            }

            // ensure type dict was initialized
            if self.addressMapping[type] == nil {
                self.addressMapping[type] = {}
            }

            let tickDict = self.borrowTickDict(type: type)
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

            // emit event
            emit NewChildAccountAdded(
                type: type.rawValue,
                tick: tick,
                address: childAcctCap.address
            )
        }

        /** ---- Internal Methods ---- */

        access(self)
        fun borrowTickDict(type: ChildAccountType): &{String: Address} {
            return &self.addressMapping[type] as &{String: Address}?
                ?? panic("Invalid child account type")
        }
    }

    init() {
        let identifier = "FRC20AccountsPool_".concat(self.account.address.toString())
        self.AccountsPoolStoragePath = StoragePath(identifier: identifier)!
        self.AccountsPoolPublicPath = PublicPath(identifier: identifier)!

        emit ContractInitialized()
    }
}
