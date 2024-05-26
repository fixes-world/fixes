/**
> Author: FIXeS World <https://fixes.world/>

# FRC20 Accounts Pool

The Hybrid Custody Account Pool

*/

// Third-party imports
import "MetadataViews"
import "ViewResolver"
import "FungibleToken"
import "FlowToken"
import "HybridCustody"
// Fixes imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesFungibleTokenInterface"
import "FRC20FTShared"
import "FRC20Indexer"

access(all) contract FRC20AccountsPool {

    access(all) entitlement Admin

    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()
    /// Event emitted when a new child account is added, if tick is nil, it means the child account is not a shared account
    access(all) event NewChildAccountAdded(type: UInt8, address: Address, tick: String?, key: String?)

    /* --- Variable, Enums and Structs --- */

    access(all)
    let AccountsPoolStoragePath: StoragePath
    access(all)
    let AccountsPoolPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    access(all) enum ChildAccountType: UInt8 {
        access(all) case Market
        access(all) case Staking
        access(all) case EVMAgency
        access(all) case EVMEntrustedAccount
        access(all) case GameWorld
        access(all) case FungibleToken
    }

    /// The public interface can be accessed by anyone
    ///
    access(all) resource interface PoolPublic {
        /// ---- Getters ----

        /// Returns the addresses of the FRC20 with the given type
        access(all)
        view fun getAddresses(type: ChildAccountType): {String: Address}
        /// Get Address
        access(all)
        view fun getAddress(type: ChildAccountType, _ key: String): Address?

        /// Returns the address of the FRC20 staking for the given tick
        access(all)
        view fun getFRC20StakingAddress(tick: String): Address?
        /// Returns the flow token receiver for the given tick
        access(all)
        view fun borrowFRC20StakingFlowTokenReceiver(tick: String): &{FungibleToken.Receiver}?

        /// Returns the address of the FRC20 market for the given tick
        access(all)
        view fun getFRC20MarketAddress(tick: String): Address?
        /// Returns the flow token receiver for the given tick
        access(all)
        view fun borrowFRC20MarketFlowTokenReceiver(tick: String): &{FungibleToken.Receiver}?

        /// Returns the address of the FRC20 market for the given tick
        access(all)
        view fun getMarketSharedAddress(): Address?
        /// Returns the address of the FRC20 market for the given tick
        access(all)
        view fun borrowMarketSharedFlowTokenReceiver(): &{FungibleToken.Receiver}?

        /// Returns the address of the EVM agent for the given owner address
        access(all)
        view fun getEVMAgencyAddress(_ owner: String): Address?
        /// Returns the flow token receiver for the given owner address
        access(all)
        view fun borrowEVMAgencyFlowTokenReceiver(_ owner: String): &{FungibleToken.Receiver}?

        /// Returns the address of the EVM entrusted account for the given evm address
        access(all)
        view fun getEVMEntrustedAccountAddress(_ evmAddr: String): Address?
        /// Returns the flow token receiver for the given evm address
        access(all)
        view fun borrowEVMEntrustedAccountFlowTokenReceiver(_ evmAddr: String): &{FungibleToken.Receiver}?

        /// Returns the address of the GameWorld for the given key
        access(all)
        view fun getGameWorldAddress(_ key: String): Address?
        /// Returns the flow token receiver for the given key
        access(all)
        view fun borrowGameWorldFlowTokenReceiver(_ key: String): &{FungibleToken.Receiver}?

        /// Returns the address of the FRC20 Fungible token with the given type
        access(all)
        view fun getFTContractAddress(_ tick: String): Address?
        /// Returns the flow token receiver for the given tick
        access(all)
        view fun borrowFTContractFlowTokenReceiver(_ tick: String): &{FungibleToken.Receiver}?
        /// Borrow the Fixes Fungible Token contract interface
        access(all)
        fun borrowFTContract(_ tick: String): &{FixesFungibleTokenInterface}?

        /// Execute inscription and extract FlowToken in the inscription
        access(all)
        fun executeInscription(type: ChildAccountType, _ ins: auth(Fixes.Extractable) &Fixes.Inscription)

        /// ----- Access account methods -----
        /// Borrow child's AuthAccount
        access(account)
        fun borrowChildAccount(type: ChildAccountType, _ key: String?): auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account?
        /// Borrow the writable config store
        access(account)
        fun borrowWritableConfigStore(type: ChildAccountType, _ key: String): auth(FRC20FTShared.Write) &FRC20FTShared.SharedStore?
        /// Sets up a new child account for market
        access(account)
        fun setupNewChildForMarket(tick: String, _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>)
        /// Sets up a new child account for staking
        access(account)
        fun setupNewChildForStaking(tick: String, _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>)
        /// Sets up a new child account for EVM agent
        access(account)
        fun setupNewChildForEVMAgency(owner: String, _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>)
        /// Sets up a new child account for EVM entrusted account
        access(account)
        fun setupNewChildForEVMEntrustedAccount(evmAddr: String, _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>)
        /// Sets up a new child account for some Game World
        access(account)
        fun setupNewChildForGameWorld(key: String, _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>)
        /// Sets up a new child account for FungibleToken
        access(account)
        fun setupNewChildForFungibleToken(tick: String, _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>)
    }

    /// The admin interface can only be accessed by the the account manager's owner
    ///
    access(all) resource interface PoolAdmin {
        /// Sets up a new child account
        access(Admin)
        fun setupNewSharedChildByType(
            type: ChildAccountType,
            _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>,
        )
        /// Sets up a new child account
        access(Admin)
        fun setupNewChildByKey(
            type: ChildAccountType,
            key: String,
            _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>,
        )
    }

    access(all) resource Pool: PoolPublic, PoolAdmin {
        access(self)
        let hcManagerCap: Capability<auth(HybridCustody.Manage) &HybridCustody.Manager>
        // AccountType -> Tick -> Address
        access(self)
        let addressMapping: {ChildAccountType: {String: Address}}
        // AccountType -> Address
        access(self)
        let sharedAddressMappping: {ChildAccountType: Address}

        init(
            _ hcManagerCap: Capability<auth(HybridCustody.Manage) &HybridCustody.Manager>
        ) {
            self.hcManagerCap = hcManagerCap
            self.addressMapping = {}
            self.sharedAddressMappping = {}
        }

        /** ---- Public Methods ---- */

        /// Returns the addresses of the FRC20 with the given type
        access(all)
        view fun getAddresses(type: ChildAccountType): {String: Address} {
            if let tickDict = self.addressMapping[type] {
                return tickDict
            }
            return {}
        }

        /// Get Address
        ///
        access(all)
        view fun getAddress(type: ChildAccountType, _ key: String): Address? {
            if let dict = self.borrowDict(type: type) {
                return dict[key]
            }
            return nil
        }

        /// Returns the address of the FRC20 market for the given tick
        access(all)
        view fun getFRC20MarketAddress(tick: String): Address? {
            return self.getAddress(type: ChildAccountType.Market, tick)
        }

        /// Returns the flow token receiver for the given tick
        access(all)
        view fun borrowFRC20MarketFlowTokenReceiver(tick: String): &{FungibleToken.Receiver}? {
            if let addr = self.getFRC20MarketAddress(tick: tick) {
                return Fixes.borrowFlowTokenReceiver(addr)
            }
            return nil
        }

        /// Returns the address of the FRC20 market for the given tick
        access(all)
        view fun getMarketSharedAddress(): Address? {
            return self.sharedAddressMappping[ChildAccountType.Market]
        }

        /// Returns the address of the FRC20 market for the given tick
        access(all)
        view fun borrowMarketSharedFlowTokenReceiver(): &{FungibleToken.Receiver}? {
            if let addr = self.getMarketSharedAddress() {
                return Fixes.borrowFlowTokenReceiver(addr)
            }
            return nil
        }

        /// Returns the address of the FRC20 staking for the given tick
        access(all)
        view fun getFRC20StakingAddress(tick: String): Address? {
            return self.getAddress(type: ChildAccountType.Staking, tick)
        }

        /// Returns the flow token receiver for the given tick
        access(all)
        view fun borrowFRC20StakingFlowTokenReceiver(tick: String): &{FungibleToken.Receiver}? {
            if let addr = self.getFRC20StakingAddress(tick: tick) {
                return Fixes.borrowFlowTokenReceiver(addr)
            }
            return nil
        }

        /// Returns the address of the EVM agent for the given eth address
        access(all)
        view fun getEVMAgencyAddress(_ owner: String): Address? {
            return self.getAddress(type: ChildAccountType.EVMAgency, owner)
        }

        /// Returns the flow token receiver for the given tick
        access(all)
        view fun borrowEVMAgencyFlowTokenReceiver(_ evmAddress: String): &{FungibleToken.Receiver}? {
            if let addr = self.getEVMAgencyAddress(evmAddress) {
                return Fixes.borrowFlowTokenReceiver(addr)
            }
            return nil
        }


        /// Returns the address of the EVM entrusted account for the given evm address
        access(all)
        view fun getEVMEntrustedAccountAddress(_ evmAddr: String): Address? {
            return self.getAddress(type: ChildAccountType.EVMEntrustedAccount, evmAddr)
        }

        /// Returns the flow token receiver for the given evm address
        access(all)
        view fun borrowEVMEntrustedAccountFlowTokenReceiver(_ evmAddr: String): &{FungibleToken.Receiver}? {
            if let addr = self.getEVMEntrustedAccountAddress(evmAddr) {
                return Fixes.borrowFlowTokenReceiver(addr)
            }
            return nil
        }

        /// Returns the address of the GameWorld for the given key
        access(all)
        view fun getGameWorldAddress(_ key: String): Address? {
            return self.getAddress(type: ChildAccountType.GameWorld, key)
        }

        /// Returns the flow token receiver for the given key
        access(all)
        view fun borrowGameWorldFlowTokenReceiver(_ key: String): &{FungibleToken.Receiver}? {
            if let addr = self.getGameWorldAddress(key) {
                return Fixes.borrowFlowTokenReceiver(addr)
            }
            return nil
        }

        /// Returns the address of the FRC20 Fungible token with the given type
        access(all)
        view fun getFTContractAddress(_ tick: String): Address? {
            return self.getAddress(type: ChildAccountType.FungibleToken, tick)
        }

        /// Returns the flow token receiver for the given tick
        access(all)
        view fun borrowFTContractFlowTokenReceiver(_ tick: String): &{FungibleToken.Receiver}? {
            if let addr = self.getFTContractAddress(tick) {
                return Fixes.borrowFlowTokenReceiver(addr)
            }
            return nil
        }

        /// Borrow the Fixes Fungible Token contract interface
        /// If the tick starts with "$", it will borrow FixesFungibleToken, otherwise FRC20FungibleToken
        /// If no contract is found, it will panic
        ///
        access(all)
        fun borrowFTContract(_ tick: String): &{FixesFungibleTokenInterface}? {
            // try to borrow the account to check if it was created
            if let childAcctRef = self.borrowChildAccount(type: ChildAccountType.FungibleToken, tick) {
                let name = tick[0] == "$" ? "FixesFungibleToken" : "FRC20FungibleToken"
                // try to borrow the contract
                return childAcctRef.contracts.borrow<&{FixesFungibleTokenInterface}>(name: name)
            }
            return nil
        }

        /// Execute inscription and extract FlowToken in the inscription
        ///
        access(all)
        fun executeInscription(type: ChildAccountType, _ ins: auth(Fixes.Extractable) &Fixes.Inscription) {
            pre {
                ins.isExtractable(): "The inscription must be extractable"
            }
            post {
                ins.isExtracted(): "The inscription must be extracted"
            }
            let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
            assert(
                meta["op"] == "exec",
                message: "The inscription operation must be 'exec'"
            )
            assert(
                meta["usage"] != nil,
                message: "The usage is not found"
            )
            let tick = meta["tick"] ?? panic("The ticker name is not found")

            // extract the tokens
            let extractedToken <- ins.extract()
            let totalAmount = extractedToken.balance

            // 1/4 -> Platform Staking Account
            let globalStore = FRC20FTShared.borrowGlobalStoreRef()
            let stakingFRC20Tick = FRC20FTShared.getPlatformStakingTickerName()
            if let addr = self.getAddress(type: ChildAccountType.Staking, stakingFRC20Tick) {
                if let stakingFlowReciever = Fixes.borrowFlowTokenReceiver(addr) {
                    // withdraw the tokens to the treasury
                    stakingFlowReciever.deposit(from: <- extractedToken.withdraw(amount: totalAmount * 0.4))
                }
            }

            // 1/3 -> Token Child Account
            if let addr = self.getAddress(type: type, tick) {
                if let tickRelatedFlowReciever = Fixes.borrowFlowTokenReceiver(addr) {
                    // the target account
                    tickRelatedFlowReciever.deposit(from: <- extractedToken.withdraw(amount: totalAmount * 0.3))
                }
            }

            // 1/3 -> Protocol(System Account)
            let systemFlowReciever = Fixes.borrowFlowTokenReceiver(self.owner?.address!)
                ?? panic("Failed to borrow system flow token receiver")
            // remaining the extracted tokens will be sent to the system account
            systemFlowReciever.deposit(from: <- extractedToken)
        }

        /// ----- Access account methods -----
        /// Borrow child's AuthAccount
        ///
        access(account)
        fun borrowChildAccount(type: ChildAccountType, _ key: String?): auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account? {
            let hcManagerRef = self.hcManagerCap.borrow()
                ?? panic("Failed to borrow hcManager")
            if let specified = key {
                let dict = self.borrowDict(type: type)
                if dict == nil {
                    return nil
                }
                if let childAddr = dict![specified] {
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

        /// Borrow the writable config store
        ///
        access(account)
        fun borrowWritableConfigStore(type: ChildAccountType, _ key: String): auth(FRC20FTShared.Write) &FRC20FTShared.SharedStore? {
            if let child = self.borrowChildAccount(type: type, key) {
                return child.storage
                    .borrow<auth(FRC20FTShared.Write)&FRC20FTShared.SharedStore>(
                        from: FRC20FTShared.SharedStoreStoragePath
                    )
            }
            return nil
        }

        /// Sets up a new child account for market
        ///
        access(account)
        fun setupNewChildForMarket(tick: String, _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>) {
            self.setupNewChildByKey(type: ChildAccountType.Market, key: tick, acctCap)
        }

        /// Sets up a new child account for staking
        ///
        access(account)
        fun setupNewChildForStaking(tick: String, _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>) {
            self.setupNewChildByKey(type: ChildAccountType.Staking, key: tick, acctCap)
        }

        /// Sets up a new child account for EVM agency
        access(account)
        fun setupNewChildForEVMAgency(owner: String, _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>) {
            self.setupNewChildByKey(type: ChildAccountType.EVMAgency, key: owner, acctCap)
        }

        /// Sets up a new child account for EVM entrusted account
        access(account)
        fun setupNewChildForEVMEntrustedAccount(evmAddr: String, _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>) {
            self.setupNewChildByKey(type: ChildAccountType.EVMEntrustedAccount, key: evmAddr, acctCap)
        }

        /// Sets up a new child account for some Game World
        access(account)
        fun setupNewChildForGameWorld(key: String, _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>) {
            self.setupNewChildByKey(type: ChildAccountType.GameWorld, key: key, acctCap)
        }

        /// Sets up a new child account for FungibleToken
        access(account)
        fun setupNewChildForFungibleToken(tick: String, _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>) {
            self.setupNewChildByKey(type: ChildAccountType.FungibleToken, key: tick, acctCap)
        }

        /** ---- Admin Methods ---- */

        /// Sets up a new shared child account
        ///
        access(Admin)
        fun setupNewSharedChildByType(
            type: ChildAccountType,
            _ childAcctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>,
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
                key: nil,
            )
        }

        /// Sets up a new child account
        ///
        access(Admin)
        fun setupNewChildByKey(
            type: ChildAccountType,
            key: String,
            _ childAcctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>,
        ) {
            pre {
                childAcctCap.check(): "Child account capability is invalid"
            }
            self._ensureDictExists(type)

            let dict = self.borrowDict(type: type) ?? panic("Failed to borrow tick ")
            // no need to setup if already exists
            if dict[key] != nil {
                return
            }

            var tick: String? = nil
            // For Market and Staking, we need to ensure the token meta exists
            if type == ChildAccountType.Market || type == ChildAccountType.Staking {
                let frc20Indexer = FRC20Indexer.getIndexer()
                // ensure token meta exists
                let tokenMeta = frc20Indexer.getTokenMeta(tick: key)
                assert(
                    tokenMeta != nil,
                    message: "Token meta does not exist"
                )
                tick = key
            }

            // record new child account address
            dict[key] = childAcctCap.address

            // setup new child account
            self._setupChildAccount(childAcctCap)

            // emit event
            emit NewChildAccountAdded(
                type: type.rawValue,
                address: childAcctCap.address,
                tick: tick,
                key: key,
            )
        }

        /** ---- Internal Methods ---- */

        /// Sets up a new child account
        ///
        access(self)
        fun _setupChildAccount(
            _ childAcctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>,
        ) {

            let hcManager = self.hcManagerCap.borrow() ?? panic("Failed to borrow hcManager")
            let hcManagerAddr = self.hcManagerCap.address

            // >>> [0] Get child AuthAccount
            var child = childAcctCap.borrow()
                ?? panic("Failed to borrow child account")

            // >>> [1] Child: createOwnedAccount
            if child.storage.borrow<&AnyResource>(from: HybridCustody.OwnedAccountStoragePath) == nil {
                let ownedAccount <- HybridCustody.createOwnedAccount(acct: childAcctCap)
                child.storage.save(<-ownedAccount, to: HybridCustody.OwnedAccountStoragePath)
            }

            // ensure owned account exists
            let childRef = child.storage
                .borrow<auth(HybridCustody.Owner) &HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
                ?? panic("owned account not found")

            // check that paths are all configured properly
            // public path
            // @deprecated after Cadence 1.0
            child.capabilities.unpublish(HybridCustody.OwnedAccountPublicPath)
            child.capabilities.publish(
                child.capabilities.storage.issue<&HybridCustody.OwnedAccount>(HybridCustody.OwnedAccountStoragePath),
                at: HybridCustody.OwnedAccountPublicPath
            )

            let publishIdentifier = HybridCustody.getOwnerIdentifier(hcManagerAddr)
            // give ownership to manager
            childRef.giveOwnership(to: hcManagerAddr)

            // only childRef will be available after 'giveaway', so we need to re-borrow it
            child = childRef.borrowAccount()

            // unpublish the priv capability
            child.inbox.unpublish<
                auth(HybridCustody.Owner) &{HybridCustody.OwnedAccountPrivate, HybridCustody.OwnedAccountPublic, ViewResolver.Resolver}
            >(publishIdentifier)

            // >> [2] manager: add owned child account

            // Link a Capability for the new owner, retrieve & publish
            let ownedPrivCap = child.capabilities.storage
                .issue<auth(HybridCustody.Owner) &{HybridCustody.OwnedAccountPrivate, HybridCustody.OwnedAccountPublic, ViewResolver.Resolver}>(HybridCustody.OwnedAccountStoragePath)
            assert(ownedPrivCap.check(), message: "Failed to get owned account capability")

            // add owned account to manager
            hcManager.addOwnedAccount(cap: ownedPrivCap)
        }

        /// Borrow dictioinary
        ///
        access(self)
        view fun borrowDict(type: ChildAccountType): auth(Mutate) &{String: Address}? {
            return &self.addressMapping[type]
        }

        /// ensure type dict exists
        ///
        access(self)
        fun _ensureDictExists(_ type: ChildAccountType) {
            if self.addressMapping[type] == nil {
                self.addressMapping[type] = {}
            }
        }
    }

    /* --- Public Methods --- */

    /// Returns the public account manager interface
    ///
    access(all)
    fun borrowAccountsPool(): &{PoolPublic} {
        return self.account
            .capabilities.get<&{PoolPublic}>(self.AccountsPoolPublicPath)
            .borrow()
            ?? panic("Could not borrow accounts pool reference")
    }

    init() {
        let identifier = "FRC20AccountsPool_".concat(self.account.address.toString())
        self.AccountsPoolStoragePath = StoragePath(identifier: identifier)!
        self.AccountsPoolPublicPath = PublicPath(identifier: identifier)!

        // create account manager with hybrid custody manager capability
        if self.account.storage.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) == nil {
            let m <- HybridCustody.createManager(filter: nil)
            self.account.storage.save(<- m, to: HybridCustody.ManagerStoragePath)
        }

        // reset account manager paths
        self.account.capabilities.unpublish(HybridCustody.ManagerPublicPath)
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&{HybridCustody.ManagerPublic}>(HybridCustody.ManagerStoragePath),
            at: HybridCustody.ManagerPublicPath
        )

        let cap = self.account.capabilities.storage
            .issue<auth(HybridCustody.Manage) &HybridCustody.Manager>(HybridCustody.ManagerStoragePath)

        // init account manager
        let acctPool <- create Pool(cap)
        self.account.storage.save(<- acctPool, to: self.AccountsPoolStoragePath)
        // link public capability
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&{PoolPublic}>(self.AccountsPoolStoragePath),
            at: self.AccountsPoolPublicPath
        )

        emit ContractInitialized()
    }
}
