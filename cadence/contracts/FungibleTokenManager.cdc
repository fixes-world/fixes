/**
> Author: FIXeS World <https://fixes.world/>

# Fungible Token Manager

This contract is used to manage the account and contract of Fixes' Fungible Tokens

*/
// Third Party Imports
import "FungibleToken"
import "FlowToken"
import "StringUtils"
import "MigrationContractStaging"
import "FTViewUtils"
import "ViewResolver"
import "FungibleTokenMetadataViews"
// Fixes imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesHeartbeat"
import "FixesFungibleTokenInterface"
import "FixesTradablePool"
import "FixesTokenLockDrops"
import "FixesTokenAirDrops"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20AccountsPool"
import "FRC20TradingRecord"
import "FRC20StakingManager"
import "FRC20Agents"
import "FRC20Converter"

/// The Manager contract for Fungible Token
///
access(all) contract FungibleTokenManager {

    access(all) entitlement Sudo

    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()
    /// Event emitted when a new Fungible Token Account is created
    access(all) event FungibleTokenAccountCreated(
        symbol: String,
        account: Address,
        by: Address
    )
    /// Event emitted when the contract of Fungible Token is updated
    access(all) event FungibleTokenManagerUpdated(
        symbol: String,
        manager: Address,
        flag: Bool
    )
    /// Event emitted when the resources of a Fungible Token Account are updated
    access(all) event FungibleTokenAccountResourcesUpdated(
        symbol: String,
        account: Address,
    )
    /// Event emitted when the contract of FRC20 Fungible Token is updated
    access(all) event FungibleTokenContractUpdated(
        symbol: String,
        account: Address,
        contractName: String
    )

    /* --- Variable, Enums and Structs --- */
    access(all)
    let AdminStoragePath: StoragePath
    access(all)
    let AdminPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    access(all) resource interface AdminPublic {
        /// get the list of initialized fungible tokens
        access(all)
        view fun getFungibleTokens(): [String]
        /// get the address of the fungible token account
        access(all)
        view fun getFungibleTokenAccount(tick: String): Address?
    }

    /// Admin Resource, represents an admin resource and store in admin's account
    ///
    access(all) resource Admin: AdminPublic {

        // ---- Public Methods ----

        /// get the list of initialized fungible tokens
        ///
        access(all)
        view fun getFungibleTokens(): [String] {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            let dict = acctsPool.getAddresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
            return dict.keys
        }

        /// get the address of the fungible token account
        access(all)
        view fun getFungibleTokenAccount(tick: String): Address? {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            return acctsPool.getFTContractAddress(tick)
        }

        // ---- Developer Methods ----

        /// update all children contracts
        access(Sudo)
        fun updateAllChildrenContracts() {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            let dict = acctsPool.getAddresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
            let ticks = dict.keys
            // update the contracts
            for tick in ticks {
                if tick[0] == "$" {
                    FungibleTokenManager._updateFungibleTokenContractInAccount(tick, contractName: "FixesFungibleToken")
                } else {
                    FungibleTokenManager._updateFungibleTokenContractInAccount(tick, contractName: "FRC20FungibleToken")
                }
            }
        }

        // migrate all children contracts
        access(Sudo)
        fun stageAllChildrenContracts() {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            let dict = acctsPool.getAddresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
            let ticks = dict.keys
            // get the statged template codes
            let serviceAddr = Fixes.getPlatformAddress()
            let codes: {String: String} = {}
            codes["FixesFungibleToken"] = MigrationContractStaging.getStagedContractCode(address: serviceAddr, name: "FixesFungibleToken")
            codes["FRC20FungibleToken"] = MigrationContractStaging.getStagedContractCode(address: serviceAddr, name: "FRC20FungibleToken")
            assert(
                codes["FixesFungibleToken"] != nil && codes["FRC20FungibleToken"] != nil,
                message: "The staged contract codes are not found"
            )
            // migrate the contracts
            for tick in ticks {
                let ftContractName = tick[0] == "$" ? "FixesFungibleToken" : "FRC20FungibleToken"
                let ftContractCode = codes[ftContractName]!
                if let acct = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick) {
                    if acct.storage.borrow<&MigrationContractStaging.Host>(from: MigrationContractStaging.HostStoragePath) == nil {
                        acct.storage.save(<-MigrationContractStaging.createHost(), to: MigrationContractStaging.HostStoragePath)
                    }
                    // Assign Host reference
                    let hostRef = acct.storage.borrow<&MigrationContractStaging.Host>(from: MigrationContractStaging.HostStoragePath)!
                    MigrationContractStaging.stageContract(host: hostRef, name: ftContractName, code: ftContractCode)
                }
            }
        }
    }

    // ---------- Manager Resource ----------

    // Add deployer Resrouce to record all coins minted by the deployer

    access(all) resource interface ManagerPublic {
        access(all)
        view fun getManagedFungibleTokens(): [String]
        access(all)
        view fun getManagedFungibleTokenAddresses(): [Address]
        access(all)
        view fun getManagedFungibleTokenAmount(): Int
        access(all)
        view fun getCreatedFungibleTokens(): [String]
        access(all)
        view fun getCreatedFungibleTokenAddresses(): [Address]
        access(all)
        view fun getCreatedFungibleTokenAmount(): Int
        // ----- Internal Methods -----
        access(contract)
        fun setFungibleTokenManaged(_ symbol: String, flag: Bool)
        access(contract)
        fun addCreatedFungibleToken(_ symbol: String)
    }

    access(all) resource Manager: ManagerPublic {
        access(self)
        let managedSymbols: [String]
        access(self)
        let createdSymbols: [String]

        init() {
            self.managedSymbols = []
            self.createdSymbols = []
        }

        // ---- Public Methods ----

        access(all)
        view fun getManagedFungibleTokens(): [String] {
            return self.managedSymbols
        }

        access(all)
        view fun getManagedFungibleTokenAddresses(): [Address] {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            var addrs: [Address] = []
            for symbol in self.managedSymbols {
                if let addr = acctsPool.getFTContractAddress(symbol) {
                    addrs = addrs.concat([addr])
                }
            }
            return addrs
        }

        access(all)
        view fun getManagedFungibleTokenAmount(): Int {
            return self.managedSymbols.length
        }

        access(all)
        view fun getCreatedFungibleTokens(): [String] {
            return self.createdSymbols
        }

        access(all)
        view fun getCreatedFungibleTokenAddresses(): [Address] {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            var addrs: [Address] = []
            for symbol in self.createdSymbols {
                if let addr = acctsPool.getFTContractAddress(symbol) {
                    addrs = addrs.concat([addr])
                }
            }
            return addrs
        }

        access(all)
        view fun getCreatedFungibleTokenAmount(): Int {
            return self.createdSymbols.length
        }

        // ---- Admin Methods ----

        /// Borrow the shared store of the managed fungible token
        ///
        access(Sudo)
        fun borrowManagedFTStore(_ symbol: String): auth(FRC20FTShared.Write) &FRC20FTShared.SharedStore {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            let accountKey = symbol[0] != "$" ? "$".concat(symbol) : symbol
            assert(
                self.managedSymbols.contains(accountKey) || self.createdSymbols.contains(accountKey),
                message: "The fungible token is not managed by the owner"
            )
            let acct = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, accountKey)
                ?? panic("The child account was not created")
            return acct.storage.borrow<auth(FRC20FTShared.Write) &FRC20FTShared.SharedStore>(from: FRC20FTShared.SharedStoreStoragePath)
                ?? panic("The shared store is not found")
        }

        // ---- Internal Methods ----

        /// set the managed fungible token
        ///
        access(contract)
        fun setFungibleTokenManaged(_ symbol: String, flag: Bool) {
            let isManaged = self.managedSymbols.contains(symbol)
            var isUpdated = false
            if flag && !isManaged {
                self.managedSymbols.append(symbol)
                isUpdated = true
            } else if !flag && isManaged {
                self.managedSymbols.remove(at: self.managedSymbols.firstIndex(of: symbol)!)
                isUpdated = true
            }

            if isUpdated {
                emit FungibleTokenManagerUpdated(symbol: symbol, manager: self.owner?.address!, flag: flag)
            }
        }

        /// set the created fungible token
        ///
        access(contract)
        fun addCreatedFungibleToken(_ symbol: String) {
            if !self.createdSymbols.contains(symbol) {
                self.createdSymbols.append(symbol)
                self.setFungibleTokenManaged(symbol, flag: true)
            }
        }
    }

    /// Create the Manager Resource
    ///
    access(all)
    fun createManager(): @Manager {
        return <- create Manager()
    }

    /// The storage path of Manager resource
    ///
    access(all)
    view fun getManagerStoragePath(): StoragePath {
        let identifier = "FungibleTokenManager_".concat(self.account.address.toString())
        return StoragePath(identifier: identifier.concat("_manager"))!
    }

    /// The public path of Manager resource
    ///
    access(all)
    view fun getManagerPublicPath(): PublicPath {
        let identifier = "FungibleTokenManager_".concat(self.account.address.toString())
        return PublicPath(identifier: identifier.concat("_manager"))!
    }

    /// Borrow the Manager Resource
    ///
    access(all)
    view fun borrowFTManager(_ addr: Address): &Manager? {
        return getAccount(addr)
            .capabilities.get<&Manager>(self.getManagerPublicPath())
            .borrow()
    }

    /** ------- Public Methods ---- */

    /// Check if the Fungible Token Symbol is already enabled
    ///
    access(all)
    view fun isTokenSymbolEnabled(_ tick: String): Bool {
        return self.getFTContractAddress(tick) != nil
    }

    /// Get the Fungible Token Account Address
    ///
    access(all)
    view fun getFTContractAddress(_ tick: String): Address? {
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        return acctsPool.getFTContractAddress(tick)
    }

    /// Borrow the global public of Fixes Fungible Token contract
    ///
    access(all)
    view fun borrowFTGlobalPublic(_ tick: String): &{FixesFungibleTokenInterface.IGlobalPublic}? {
        // singleton resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        // borrow the contract
        if let contractRef = acctsPool.borrowFTContract(tick) {
            return contractRef.borrowGlobalPublic()
        }
        return nil
    }

    /// Borrow the ft interface
    ///
    access(all)
    view fun borrowFixesFTInterface(_ addr: Address): &{FixesFungibleTokenInterface}? {
        let ftAcct = getAccount(addr)
        var ftName = "FixesFungibleToken"
        var ftContract = ftAcct.contracts.borrow<&{FixesFungibleTokenInterface}>(name: ftName)
        if ftContract == nil {
            ftName = "FRC20FungibleToken"
            ftContract = ftAcct.contracts.borrow<&{FixesFungibleTokenInterface}>(name: ftName)
        }
        return ftContract
    }

    /// Check if the user is authorized to access the Fixes Fungible Token manager
    ///
    access(all)
    view fun isFTContractAuthorizedUser(_ tick: String, _ callerAddr: Address): Bool {
        let globalPublicRef = self.borrowFTGlobalPublic(tick)
        return globalPublicRef?.isAuthorizedUser(callerAddr) ?? false
    }

    /// Build the Standard Token View
    ///
    access(all)
    fun buildStandardTokenView(_ ftAddress: Address, _ ftName: String): FTViewUtils.StandardTokenView? {
        if let viewResolver = getAccount(ftAddress).contracts.borrow<&{ViewResolver}>(name: ftName) {
            let vaultData = viewResolver.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
            let display = viewResolver.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?
            if vaultData == nil || display == nil {
                return nil
            }
            return FTViewUtils.StandardTokenView(
                identity: FTViewUtils.FTIdentity(ftAddress, ftName),
                decimals: 8,
                tags: [],
                dataSource: ftAddress,
                paths: FTViewUtils.StandardTokenPaths(
                    vaultPath: vaultData!.storagePath,
                    balancePath: vaultData!.metadataPath,
                    receiverPath: vaultData!.receiverPath,
                ),
                display: FTViewUtils.FTDisplayWithSource(ftAddress, display!),
            )
        }
        return nil
    }

    /// The struct of Fixes Token View
    ///
    access(all) struct FixesTokenView {
        access(all) let standardView: FTViewUtils.StandardTokenView
        access(all) let deployer: Address
        access(all) let accountKey: String
        access(all) let maxSupply: UFix64
        access(all) let extra: {String: String}

        init(
            _ standardView: FTViewUtils.StandardTokenView,
            _ deployer: Address,
            _ accountKey: String,
            _ maxSupply: UFix64,
            _ extra: {String: String}
        ) {
            self.standardView = standardView
            self.deployer = deployer
            self.accountKey = accountKey
            self.maxSupply = maxSupply
            self.extra = extra
        }
    }

    /// Build the Fixes Token View
    ///
    access(all)
    fun buildFixesTokenView(_ ftAddress: Address, _ ftName: String): FixesTokenView? {
        if let ftInterface = getAccount(ftAddress).contracts.borrow<&{FixesFungibleTokenInterface}>(name: ftName) {
            let deployer = ftInterface.getDeployerAddress()
            let symbol = ftInterface.getSymbol()
            let accountKey = ftName == "FixesFungibleToken" ? "$".concat(symbol) : symbol
            let maxSupply = ftInterface.getMaxSupply() ?? UFix64.max
            if let tokenView = self.buildStandardTokenView(ftAddress, ftName) {
                return FixesTokenView(tokenView, deployer, accountKey, maxSupply, {})
            }
        }
        return nil
    }

    /// The struct of Fixes Token Modules
    ///
    access(all) struct FixesTokenModules {
        access(all) let address: Address
        access(all) let supportedMinters: [Type]

        init(
            _ address: Address,
        ) {
            self.address = address
            self.supportedMinters = []

            self.sync()
        }

        access(all)
        fun sync() {
            // Try to add tradable pool
            let tradablePool = FixesTradablePool.borrowTradablePool(self.address)
            if tradablePool != nil {
                self.supportedMinters.append(tradablePool!.getType())
            }
            // Try to add lockdrops pool
            let lockdropsPool = FixesTokenLockDrops.borrowDropsPool(self.address)
            if lockdropsPool != nil {
                self.supportedMinters.append(lockdropsPool!.getType())
            }
            // Try to add airdrops pool
            let airdropsPool = FixesTokenAirDrops.borrowAirdropPool(self.address)
            if airdropsPool != nil {
                self.supportedMinters.append(airdropsPool!.getType())
            }
        }

        access(all)
        view fun isTradablePoolSupported(): Bool {
            return self.supportedMinters.contains(Type<@FixesTradablePool.TradableLiquidityPool>())
        }

        access(all)
        view fun isLockdropsPoolSupported(): Bool {
            return self.supportedMinters.contains(Type<@FixesTokenLockDrops.DropsPool>())
        }

        access(all)
        view fun isAirdropsPoolSupported(): Bool {
            return self.supportedMinters.contains(Type<@FixesTokenAirDrops.AirdropPool>())
        }
    }

    /// The Fixes Token Info
    ///
    access(all) struct FixesTokenInfo {
        access(all) let view: FixesTokenView
        access(all) let modules: FixesTokenModules
        access(all) let extra: {String: AnyStruct}

        init(
            _ view: FixesTokenView,
            _ modules: FixesTokenModules
        ) {
            self.view = view
            self.modules = modules
            self.extra = {}
        }

        access(contract)
        fun setExtra(_ key: String, _ value: AnyStruct) {
            self.extra[key] = value
        }
    }

    /// Build the Fixes Token Info
    ///
    access(all)
    fun buildFixesTokenInfo(_ ftAddress: Address, _ acctKey: String?): FixesTokenInfo? {
        let ftAcct = getAccount(ftAddress)
        var ftName = "FixesFungibleToken"
        var ftContract: &{FixesFungibleTokenInterface}? = nil
        if acctKey != nil {
            ftName = acctKey![0] == "$" ? "FixesFungibleToken" : "FRC20FungibleToken"
            ftContract = ftAcct.contracts.borrow<&{FixesFungibleTokenInterface}>(name: ftName)
        } else {
            ftContract = ftAcct.contracts.borrow<&{FixesFungibleTokenInterface}>(name: ftName)
            if ftContract == nil {
                ftName = "FRC20FungibleToken"
                ftContract = ftAcct.contracts.borrow<&{FixesFungibleTokenInterface}>(name: ftName)
            }
        }
        if ftContract == nil {
            return nil
        }
        if let tokenView = self.buildFixesTokenView(ftAddress, ftName) {
            let modules = FixesTokenModules(ftAddress)
            let info = FixesTokenInfo(tokenView, modules)
            var totalAllocatedSupply = 0.0
            var totalCirculatedSupply = 0.0
            // update modules info with extra fields
            if modules.isTradablePoolSupported() {
                let tradablePool = FixesTradablePool.borrowTradablePool(ftAddress)!
                info.setExtra("tradable:allocatedSupply", tradablePool.getTotalAllowedMintableAmount())
                info.setExtra("tradable:supplied", tradablePool.getTradablePoolCirculatingSupply())
                info.setExtra("tradable:burnedSupply", tradablePool.getBurnedTokenAmount())
                info.setExtra("tradable:flowInPool", tradablePool.getFlowBalanceInPool())
                info.setExtra("tradable:liquidityMcap", tradablePool.getLiquidityMarketCap())
                info.setExtra("tradable:targetMcap", FixesTradablePool.getTargetMarketCap())
                info.setExtra("tradable:isLocalActive", tradablePool.isLocalActive())
                info.setExtra("tradable:isHandovered", tradablePool.isLiquidityHandovered())
                info.setExtra("tradable:handoveringTime", tradablePool.getHandoveredAt())
                info.setExtra("tradable:freeAmount", tradablePool.getFreeAmount())
                info.setExtra("tradable:subjectFeePerc", tradablePool.getSubjectFeePercentage())
                info.setExtra("tradable:swapPairAddr", tradablePool.getSwapPairAddress())
                totalAllocatedSupply = totalAllocatedSupply + tradablePool.getTotalAllowedMintableAmount()
                totalCirculatedSupply = totalCirculatedSupply + tradablePool.getTotalMintedAmount()
                // update the total token market cap
                info.setExtra("token:totalValue", tradablePool.getTotalTokenValue())
                info.setExtra("token:totalMcap", tradablePool.getTotalTokenMarketCap())
                info.setExtra("token:price", tradablePool.getTokenPriceInFlow())
                info.setExtra("token:priceByLiquidity", tradablePool.getTokenPriceByInPoolLiquidity())
            }
            if modules.isLockdropsPoolSupported() {
                let lockdropsPool = FixesTokenLockDrops.borrowDropsPool(ftAddress)!
                info.setExtra("lockdrops:allocatedSupply", lockdropsPool.getTotalAllowedMintableAmount())
                info.setExtra("lockdrops:supplied", lockdropsPool.getTotalMintedAmount())
                info.setExtra("lockdrops:lockingTicker", lockdropsPool.getLockingTokenTicker())
                info.setExtra("lockdrops:isClaimable", lockdropsPool.isClaimable())
                info.setExtra("lockdrops:isActivated", lockdropsPool.isActivated())
                info.setExtra("lockdrops:activatingTime", lockdropsPool.getActivatingTime())
                info.setExtra("lockdrops:isDeprecated", lockdropsPool.isDeprecated())
                info.setExtra("lockdrops:deprecatingTime", lockdropsPool.getDeprecatingTime())
                info.setExtra("lockdrops:currentMintableAmount", lockdropsPool.getCurrentMintableAmount())
                info.setExtra("lockdrops:unclaimedSupply", lockdropsPool.getUnclaimedBalanceInPool())
                info.setExtra("lockdrops:totalLockedAmount",lockdropsPool.getTotalLockedTokenBalance())
                let lockingPeriods = lockdropsPool.getLockingPeriods()
                for i, period in lockingPeriods {
                    let periodKey = "lockdrops:lockingChoice.".concat(i.toString()).concat(".")
                    info.setExtra(periodKey.concat("period"), period)
                    info.setExtra(periodKey.concat("rate"), lockdropsPool.getExchangeRate(period))
                }
                totalAllocatedSupply = totalAllocatedSupply + lockdropsPool.getTotalAllowedMintableAmount()
                totalCirculatedSupply = totalCirculatedSupply + lockdropsPool.getTotalMintedAmount()
            }
            if modules.isAirdropsPoolSupported() {
                let airdropsPool = FixesTokenAirDrops.borrowAirdropPool(ftAddress)!
                info.setExtra("airdrops:allocatedSupply", airdropsPool.getTotalAllowedMintableAmount())
                info.setExtra("airdrops:supplied", airdropsPool.getTotalMintedAmount())
                info.setExtra("airdrops:isClaimable", airdropsPool.isClaimable())
                info.setExtra("airdrops:currentMintableAmount", airdropsPool.getCurrentMintableAmount())
                info.setExtra("airdrops:totalClaimableAmount", airdropsPool.getTotalClaimableAmount())
                totalAllocatedSupply = totalAllocatedSupply + airdropsPool.getTotalAllowedMintableAmount()
                totalCirculatedSupply = totalCirculatedSupply + airdropsPool.getTotalMintedAmount()
            }
            // Total Supply Metadata
            info.setExtra("total:allocatedSupply", totalAllocatedSupply)
            info.setExtra("total:supplied", totalCirculatedSupply)
            // Token Metadata
            info.setExtra("token:deployedAt", ftContract!.getDeployedAt())
            // borrow trading records
            if let records = FRC20TradingRecord.borrowTradingRecords(ftAddress) {
                let status = records.getStatus()
                info.setExtra("token:transactions", status.sales)
                info.setExtra("token:totalTradedVolume", status.volume)
                info.setExtra("token:totalTradedAmount", status.dealAmount)
            }
            // Deposit Tax Metadata
            info.setExtra("depositTax:ratio", ftContract!.getDepositTaxRatio())
            info.setExtra("depositTax:recipient", ftContract!.getDepositTaxRecipient())
            return info
        }
        return nil
    }

    /// Enable the Fixes Fungible Token
    ///
    access(all)
    fun initializeFixesFungibleTokenAccount(
        _ ins: auth(Fixes.Extractable) &Fixes.Inscription,
        newAccount: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>,
    ) {
        pre {
            ins.isExtractable(): "The inscription is not extracted"
        }
        post {
            ins.isExtracted(): "The inscription is not extracted"
        }
        // singletoken resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = self.verifyExecutingInscription(ins, usage: "init-ft")
        let tick = meta["tick"] ?? panic("The token symbol is not found")

        /// Check if the account is already enabled
        assert(
            acctsPool.getFTContractAddress(tick) == nil,
            message: "The Fungible Token account is already created"
        )

        // execute the inscription
        acctsPool.executeInscription(type: FRC20AccountsPool.ChildAccountType.FungibleToken, ins)

        // Get the caller address
        let callerAddr = ins.owner!.address
        let newAddr = newAccount.address

        // create the account for the fungible token at the accounts pool
        acctsPool.setupNewChildForFungibleToken(tick: tick, newAccount)

        // update the resources in the account
        self._ensureFungibleTokenAccountResourcesAvailable(tick, caller: callerAddr)
        // deploy the contract of Fixes Fungible Token to the account
        self._updateFungibleTokenContractInAccount(tick, contractName: "FixesFungibleToken")

        // Add token symbol to the managed list
        let managerRef = self.borrowFTManager(callerAddr) ?? panic("The manager resource is not found")
        managerRef.addCreatedFungibleToken(tick)

        // emit the event
        emit FungibleTokenAccountCreated(
            symbol: tick,
            account: newAddr,
            by: callerAddr
        )
    }

    /// Setup Tradable Pool Resources
    ///
    access(all)
    fun setupTradablePoolResources(_ ins: auth(Fixes.Extractable) &Fixes.Inscription) {
        pre {
            ins.isExtractable(): "The inscription is not extracted"
        }
        post {
            ins.isExtracted(): "The inscription is not extracted"
        }
        // singletoken resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
        let tick = meta["tick"] ?? panic("The token symbol is not found")

        let tokenAdminRef = self.borrowWritableTokenAdmin(tick: tick)
        // check if the caller is authorized
        let callerAddr = ins.owner?.address ?? panic("The owner of the inscription is not found")
        assert(
            tokenAdminRef.isAuthorizedUser(callerAddr),
            message: "You are not authorized to setup the tradable pool resources"
        )

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick)
            ?? panic("The child account was not created")

        // Get the caller address
        let ftContractAddr = childAcctRef.address

        // create a new minter from the account
        let minter <- self._initializeMinter(
            ins,
            usage: "setup-tradable-pool",
            extrafields: ["supply", "feePerc", "freeAmount"]
        )

        // - Add Tradable Pool Resource
        //   - Add Heartbeat Hook
        //   - Relink Flow Token Resource

        // add tradable pool resource
        let poolStoragePath = FixesTradablePool.getLiquidityPoolStoragePath()
        assert(
            childAcctRef.storage.borrow<&AnyResource>(from: poolStoragePath) == nil,
            message: "The tradable pool is already created"
        )

        // create the tradable pool
        let tradablePool <- FixesTradablePool.createTradableLiquidityPool(
            ins: ins,
            <- minter
        )
        childAcctRef.storage.save(<- tradablePool, to: poolStoragePath)

        // link the tradable pool to the public path
        let poolPublicPath = FixesTradablePool.getLiquidityPoolPublicPath()
        childAcctRef.capabilities.publish(
            childAcctRef.capabilities.storage.issue<&FixesTradablePool.TradableLiquidityPool>(poolStoragePath),
            at: poolPublicPath
        )

        let tradablePoolRef = childAcctRef.storage
            .borrow<auth(FixesTradablePool.Manage) &FixesTradablePool.TradableLiquidityPool>(from: poolStoragePath)
            ?? panic("The tradable pool was not created")
        // Initialize the tradable pool
        tradablePoolRef.initialize()

        // Check if the tradable pool is active
        assert(
            tradablePoolRef.isLocalActive(),
            message: "The tradable pool is not active"
        )

        // -- Add the heartbeat hook to the tradable pool

        // Register to FixesHeartbeat
        let heartbeatScope = "TradablePool"
        if !FixesHeartbeat.hasHook(scope: heartbeatScope, hookAddr: ftContractAddr) {
            FixesHeartbeat.addHook(
                scope: heartbeatScope,
                hookAddr: ftContractAddr,
                hookPath: poolPublicPath
            )
        }

        // Reset Flow Receiver
        // This is the standard receiver path of FlowToken
        let flowReceiverPath = /public/flowTokenReceiver

         // Unlink the existing receiver capability for flowReceiverPath
        if childAcctRef.capabilities.get<&{FungibleToken.Receiver}>(flowReceiverPath).check() {
            // link the forwarder to the public path
            childAcctRef.capabilities.unpublish(flowReceiverPath)
            // Link the new forwarding receiver capability
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&{FungibleToken.Receiver}>(poolStoragePath),
                at: flowReceiverPath
            )

            // link the FlowToken to the forwarder fallback path
            let fallbackPath = Fixes.getFallbackFlowTokenPublicPath()
            childAcctRef.capabilities.unpublish(fallbackPath)
            childAcctRef.capabilities.publish(
                childAcctRef.capabilities.storage.issue<&FlowToken.Vault>(/storage/flowTokenVault),
                at: fallbackPath
            )
        }

        // emit the event
        emit FungibleTokenAccountResourcesUpdated(symbol: tick, account: ftContractAddr)
    }

    access(all)
    fun setupLockDropsPool(_ ins: auth(Fixes.Extractable) &Fixes.Inscription, lockingExchangeRates: {UFix64: UFix64}) {
        pre {
            ins.isExtractable(): "The inscription is not extracted"
        }
        post {
            ins.isExtracted(): "The inscription is not extracted"
        }
        // singletoken resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = self.verifyExecutingInscription(ins, usage: "setup-lockdrops")
        let tick = meta["tick"] ?? panic("The token symbol is not found")

        let tokenAdminRef = self.borrowWritableTokenAdmin(tick: tick)
        // check if the caller is authorized
        let callerAddr = ins.owner?.address ?? panic("The owner of the inscription is not found")
        assert(
            tokenAdminRef.isAuthorizedUser(callerAddr),
            message: "You are not authorized to setup the lockdrops pool resources"
        )

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick)
            ?? panic("The child account was not created")

        // Get the caller address
        let ftContractAddr = childAcctRef.address

        // - Add Lock Drop Resource

        let lockdropsStoragePath = FixesTokenLockDrops.getDropsPoolStoragePath()
        assert(
            childAcctRef.storage.borrow<&AnyResource>(from: lockdropsStoragePath) == nil,
            message: "The lockdrops pool is already created"
        )

        // create a new minter from the account
        let minter <- self._initializeMinter(
            ins,
            usage: "setup-lockdrops",
            extrafields: ["supply", "lockingTick"]
        )

        var activateTime: UFix64? = nil
        if let activateAt = meta["activateAt"] {
            activateTime = UFix64.fromString(activateAt)
        }
        var failureDeprecatedTime: UFix64? = nil
        if let deprecatedAt = meta["deprecatedAt"] {
            failureDeprecatedTime = UFix64.fromString(deprecatedAt)
        }

        // create the lockdrops pool
        let lockdrops <- FixesTokenLockDrops.createDropsPool(
            ins,
            <- minter,
            lockingExchangeRates,
            activateTime,
            failureDeprecatedTime
        )
        childAcctRef.storage.save(<- lockdrops, to: lockdropsStoragePath)

        // link the lockdrops pool to the public path
        let lockdropsPublicPath = FixesTokenLockDrops.getDropsPoolPublicPath()
        childAcctRef.capabilities.publish(
            childAcctRef.capabilities.storage.issue<&FixesTokenLockDrops.DropsPool>(lockdropsStoragePath),
            at: lockdropsPublicPath
        )

        // emit the event
        emit FungibleTokenAccountResourcesUpdated(symbol: tick, account: ftContractAddr)
    }

    /// Enable the Airdrop pool for the Fungible Token
    ///
    access(all)
    fun setupAirdropsPool(_ ins: auth(Fixes.Extractable) &Fixes.Inscription) {
        pre {
            ins.isExtractable(): "The inscription is not extracted"
        }
        post {
            ins.isExtracted(): "The inscription is not extracted"
        }
        // singletoken resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = self.verifyExecutingInscription(ins, usage: "setup-airdrop")
        let tick = meta["tick"] ?? panic("The token symbol is not found")

        let tokenAdminRef = self.borrowWritableTokenAdmin(tick: tick)
        // check if the caller is authorized
        let callerAddr = ins.owner?.address ?? panic("The owner of the inscription is not found")
        assert(
            tokenAdminRef.isAuthorizedUser(callerAddr),
            message: "You are not authorized to setup the airdrops pool resources"
        )

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick)
            ?? panic("The child account was not created")

        // Get the caller address
        let ftContractAddr = childAcctRef.address

        // - Add Airdrop Resource

        let storagePath = FixesTokenAirDrops.getAirdropPoolStoragePath()
        assert(
            childAcctRef.storage.borrow<&AnyResource>(from: storagePath) == nil,
            message: "The airdrop pool is already created"
        )

        // create a new minter from the account
        let minter <- self._initializeMinter(
            ins,
            usage: "setup-airdrop",
            extrafields: ["supply"]
        )

        // create the airdrops pool
        let airdrops <- FixesTokenAirDrops.createDropsPool(ins, <- minter)
        childAcctRef.storage.save(<- airdrops, to: storagePath)

        // link the airdrops pool to the public path
        let publicPath = FixesTokenAirDrops.getAirdropPoolPublicPath()
        childAcctRef.capabilities.publish(
            childAcctRef.capabilities.storage.issue<&FixesTokenAirDrops.AirdropPool>(storagePath),
            at: publicPath
        )

        // emit the event
        emit FungibleTokenAccountResourcesUpdated(symbol: tick, account: ftContractAddr)
    }

    access(self)
    fun _initializeMinter(
        _ ins: auth(Fixes.Extractable) &Fixes.Inscription,
        usage: String,
        extrafields: [String]
    ): @{FixesFungibleTokenInterface.IMinter} {
        // singletoken resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = self.verifyExecutingInscription(ins, usage: usage)
        let tick = meta["tick"] ?? panic("The token symbol is not found")

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick)
            ?? panic("The child account was not created")

        // Get the caller address
        let ftContractAddr = childAcctRef.address
        let callerAddr = ins.owner!.address

        // get the token admin reference
        let tokenAdminRef = self.borrowWritableTokenAdmin(tick: tick)
        // check if the caller is authorized
        assert(
            tokenAdminRef.isAuthorizedUser(callerAddr),
            message: "You are not authorized to setup the tradable pool resources"
        )

        // borrow the super minter
        let superMinter = tokenAdminRef.borrowSuperMinter()
        assert(
            tick == "$".concat(superMinter.getSymbol()),
            message: "The token symbol is not valid"
        )

        // calculate the new minter supply
        let maxSupply = superMinter.getMaxSupply()
        let grantedSupply = tokenAdminRef.getGrantedMintableAmount()

        // check if the caller is advanced
        let isAdvancedCaller = FixesTradablePool.isAdvancedTokenPlayer(callerAddr)

        // new minter supply
        let maxSupplyForNewMinter = maxSupply.saturatingSubtract(grantedSupply)
        var newGrantedAmount = maxSupplyForNewMinter
        if let supplyStr = meta["supply"] {
            assert(
                isAdvancedCaller,
                message: "You are not eligible to setup custimzed supply amount for the tradable pool"
            )
            newGrantedAmount = UFix64.fromString(supplyStr)
                ?? panic("The supply amount is not valid")
        }
        assert(
            newGrantedAmount <= maxSupplyForNewMinter && newGrantedAmount > 0.0,
            message: "The supply amount of the minter is more than the all unused supply or less than 0.0"
        )
        var isExtraFieldsExist = false
        for fields in extrafields {
            if let value = meta[fields] {
                isExtraFieldsExist = true
                break
            }
        }
        /// Check if the caller is eligible to configure the minter with extra fields
        if isExtraFieldsExist {
            assert(
                isAdvancedCaller,
                message: "You are not eligible to configure the minter with extra fields"
            )
        }
        // create a new minter from the account
        return <- tokenAdminRef.createMinter(allowedAmount: newGrantedAmount)
    }

    /// Enable the FRC20 Fungible Token
    ///
    access(all)
    fun initializeFRC20FungibleTokenAccount(
        _ ins: auth(Fixes.Extractable) &Fixes.Inscription,
        newAccount: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>
    ) {
        // singletoken resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
        assert(
            meta["op"] == "exec" && meta["usage"] == "init-ft",
            message: "The inscription is not for initialize a Fungible Token account"
        )

        let tickerName = meta["tick"]?.toLower() ?? panic("The token tick is not found")

        /// Check if the account is already enabled
        assert(
            acctsPool.getFTContractAddress(tickerName) == nil,
            message: "The Fungible Token account is already created"
        )

        // Get the caller address
        let callerAddr = ins.owner!.address
        let newAddr = newAccount.address

        // Check if the the caller is valid
        let tokenMeta = frc20Indexer.getTokenMeta(tick: tickerName) ?? panic("The token is not registered")
        assert(
            tokenMeta.deployer == callerAddr,
            message: "You are not allowed to create the Fungible Token account"
        )

        // execute the inscription to ensure you are the deployer of the token
        let ret = frc20Indexer.executeByDeployer(ins: ins)
        assert(
            ret == true,
            message: "The inscription execution failed"
        )

        // create the account for the fungible token at the accounts pool
        acctsPool.setupNewChildForFungibleToken(
            tick: tokenMeta.tick,
            newAccount
        )

        // update the resources in the account
        self._ensureFungibleTokenAccountResourcesAvailable(tickerName, caller: callerAddr)

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tickerName)
            ?? panic("The staking account was not created")

        // Create the FRC20Agents.IndexerController and save it in the account
        // This is required for FRC20FungibleToken
        let ctrlStoragePath = FRC20Agents.getIndexerControllerStoragePath()
        if childAcctRef.storage.borrow<&AnyResource>(from: ctrlStoragePath) == nil {
            let indexerController <- FRC20Agents.createIndexerController([tickerName])
            childAcctRef.storage.save(<- indexerController, to: ctrlStoragePath)
        }

        // deploy the contract of FRC20 Fungible Token to the account
        self._updateFungibleTokenContractInAccount(tickerName, contractName: "FRC20FungibleToken")

        // Add token symbol to the managed list
        let managerRef = self.borrowFTManager(callerAddr) ?? panic("The manager resource is not found")
        managerRef.addCreatedFungibleToken(tickerName)

        // emit the event
        emit FungibleTokenAccountCreated(
            symbol: tickerName,
            account: newAddr,
            by: callerAddr
        )
    }

    /// Setup Tradable Pool Resources
    ///
    access(all)
    fun setupFRC20ConverterResources(_ ins: auth(Fixes.Extractable) &Fixes.Inscription) {
        pre {
            ins.isExtractable(): "The inscription is not extracted"
        }
        post {
            ins.isExtracted(): "The inscription is not extracted"
        }
        // singletoken resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        let frc20Indexer = FRC20Indexer.getIndexer()

        // inscription data
        let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
        let tickerName = meta["tick"]?.toLower() ?? panic("The token tick is not found")

        let callerAddr = ins.owner!.address

        // Check if the the caller is valid
        let tokenMeta = frc20Indexer.getTokenMeta(tick: tickerName) ?? panic("The token is not registered")
        assert(
            tokenMeta.deployer == callerAddr,
            message: "You are not allowed to create the Fungible Token account"
        )

        // execute the inscription to ensure you are the deployer of the token
        let ret = frc20Indexer.executeByDeployer(ins: ins)
        assert(
            ret == true,
            message: "The inscription execution failed"
        )

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tickerName)
            ?? panic("The child account was not created")

        // Get the caller address
        let ftContractAddr = childAcctRef.address

        // --- Create the FRC20 Converter ---

        // Check if the admin resource is available
        let contractRef = acctsPool.borrowFTContract(tickerName)
            ?? panic("The Fungible Token account was not created")
        let adminStoragePath = contractRef.getAdminStoragePath()

        let adminCap = childAcctRef.capabilities.storage
            .issue<auth(FixesFungibleTokenInterface.Manage) &{FixesFungibleTokenInterface.IAdminWritable}>(adminStoragePath)
         assert(
            adminCap.check(),
            message: "The admin resource is not available"
        )
        let converterStoragePath = FRC20Converter.getFTConverterStoragePath()
        childAcctRef.storage.save(<- FRC20Converter.createConverter(adminCap), to: converterStoragePath)
        // link the converter to the public path
        childAcctRef.capabilities.publish(
            childAcctRef.capabilities.storage.issue<&FRC20Converter.FTConverter>(converterStoragePath),
            at: FRC20Converter.getFTConverterPublicPath()
        )

        // emit the event
        emit FungibleTokenAccountResourcesUpdated(symbol: tickerName, account: ftContractAddr)
    }

    /** ---- Internal Methods ---- */

    /// Verify the inscription for executing the Fungible Token
    ///
    access(self)
    fun verifyExecutingInscription(
        _ ins: auth(Fixes.Extractable) &Fixes.Inscription,
        usage: String
    ): {String: String} {
        // inscription data
        let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
        assert(
            meta["op"] == "exec",
            message: "The inscription operation must be 'exec'"
        )
        let tick = meta["tick"] ?? panic("The token symbol is not found")
        assert(
            tick[0] == "$",
            message: "The token symbol must start with '$'"
        )
        let usageInMeta = meta["usage"] ?? panic("The token operation is not found")
        assert(
            usageInMeta == usage || usage == "*",
            message: "The inscription is not for initialize a Fungible Token account"
        )
        return meta
    }

    /// Borrow the Fixes Fungible Token Admin Resource
    ///
    access(self)
    view fun borrowWritableTokenAdmin(tick: String): auth(FixesFungibleTokenInterface.Manage) &{FixesFungibleTokenInterface.IAdminWritable} {
        // try to borrow the account to check if it was created
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick)
            ?? panic("The Fungible token account was not created")
        let contractRef = acctsPool.borrowFTContract(tick)
            ?? panic("The Fungible Token contract is not deployed")
        // Check if the admin resource is available
        let adminStoragePath = contractRef.getAdminStoragePath()
        return childAcctRef.storage
            .borrow<auth(FixesFungibleTokenInterface.Manage) &{FixesFungibleTokenInterface.IAdminWritable}>(from: adminStoragePath)
            ?? panic("The admin resource is not available")
    }

    /// Ensure all resources are available
    ///
    access(self)
    fun _ensureFungibleTokenAccountResourcesAvailable(_ tick: String, caller: Address) {
        // singleton resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick)
            ?? panic("The staking account was not created")
        let childAddr = childAcctRef.address

        var isUpdated = false
        // The fungible token should have the following resources in the account:
        // - FRC20FTShared.SharedStore: configuration
        //   - Store the Symbol, Name for the token
        //   - Store the Deployer of the token
        //   - Store the Deploying Time of the token

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

        // borrow the shared store
        if let store = childAcctRef.storage
            .borrow<auth(FRC20FTShared.Write) &FRC20FTShared.SharedStore>(from: FRC20FTShared.SharedStoreStoragePath) {
            // ensure the symbol is without the '$' sign
            var symbol = tick
            if symbol[0] == "$" {
                symbol = symbol.slice(from: 1, upTo: symbol.length)
            }
            // set the configuration
            store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenDeployer, value: caller)
            store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol, value: symbol)
            store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenDeployedAt, value: getCurrentBlock().timestamp)

            isUpdated = true || isUpdated
        }

        isUpdated = self._ensureTradingRecordResourcesAvailable(childAcctRef, tick: tick) || isUpdated

        if isUpdated {
            emit FungibleTokenAccountResourcesUpdated(symbol: tick, account: childAddr)
        }
    }

    /// Utility method to ensure the trading record resources are available
    ///
    access(self)
    fun _ensureTradingRecordResourcesAvailable(_ acctRef: auth(Storage, Capabilities) &Account, tick: String?): Bool {
        var isUpdated = false

        // - FRC20FTShared.Hooks
        //   - TradingRecord

        // create the hooks and save it in the account
        if acctRef.storage.borrow<&AnyResource>(from: FRC20FTShared.TransactionHookStoragePath) == nil {
            let hooks <- FRC20FTShared.createHooks()
            acctRef.storage.save(<- hooks, to: FRC20FTShared.TransactionHookStoragePath)

            isUpdated = true || isUpdated
        }

        // link the hooks to the public path
        if acctRef
            .capabilities.get<&FRC20FTShared.Hooks>(FRC20FTShared.TransactionHookPublicPath)
            .borrow() == nil {
            // link the hooks to the public path
            acctRef.capabilities.unpublish(FRC20FTShared.TransactionHookPublicPath)
            acctRef.capabilities.publish(
                acctRef.capabilities.storage.issue<&FRC20FTShared.Hooks>(FRC20FTShared.TransactionHookStoragePath),
                at: FRC20FTShared.TransactionHookPublicPath
            )

            isUpdated = true || isUpdated
        }

        // ensure trading records are available
        if acctRef.storage.borrow<&AnyResource>(from: FRC20TradingRecord.TradingRecordsStoragePath) == nil {
            let tradingRecords <- FRC20TradingRecord.createTradingRecords(tick)
            acctRef.storage.save(<- tradingRecords, to: FRC20TradingRecord.TradingRecordsStoragePath)

            // link the trading records to the public path
            acctRef.capabilities.unpublish(FRC20TradingRecord.TradingRecordsPublicPath)
            acctRef.capabilities.publish(
                acctRef.capabilities.storage.issue<&FRC20TradingRecord.TradingRecords>(FRC20TradingRecord.TradingRecordsStoragePath),
                at: FRC20TradingRecord.TradingRecordsPublicPath
            )

            isUpdated = true || isUpdated
        }

        // borrow the hooks reference
        let hooksRef = acctRef.storage
            .borrow<auth(FRC20FTShared.Manage) &FRC20FTShared.Hooks>(from: FRC20FTShared.TransactionHookStoragePath)
            ?? panic("The hooks were not created")

        // add the trading records to the hooks, if it is not added yet
        // get the public capability of the trading record hook
        let tradingRecordsCap = acctRef
            .capabilities.get<&FRC20TradingRecord.TradingRecords>(
                FRC20TradingRecord.TradingRecordsPublicPath
            )
        assert(tradingRecordsCap.check(), message: "The trading record hook is not valid")
        // get the reference of the trading record hook
        let recordsRef = tradingRecordsCap.borrow()
            ?? panic("The trading record hook is not valid")
        if !hooksRef.hasHook(recordsRef.getType()) {
            hooksRef.addHook(tradingRecordsCap)
        }

        return isUpdated
    }

    /// Update the FRC20 Fungible Token contract in the account
    ///
    access(self)
    fun _updateFungibleTokenContractInAccount(_ tick: String, contractName: String) {
        // singleton resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick)
            ?? panic("The staking account was not created")
        let childAddr = childAcctRef.address

        // Load contract from the account
        if let ftContract = self.account.contracts.get(name: contractName) {
            // try to deploy the contract of FRC20 Fungible Token to the child account
            let deployedContracts = childAcctRef.contracts.names
            if deployedContracts.contains(contractName) {
                log("Updating the contract in the account: ".concat(childAddr.toString()))
                // update the contract
                childAcctRef.contracts.update(name: contractName, code: ftContract.code)
            } else {
                log("Deploying the contract to the account: ".concat(childAddr.toString()))
                // add the contract
                childAcctRef.contracts.add(name: contractName, code: ftContract.code)
            }
        } else {
            panic("The contract of Fungible Token is not deployed")
        }

        // emit the event
        emit FungibleTokenContractUpdated(symbol: tick, account: childAddr, contractName: contractName)
    }

    init() {
        let identifier = "FungibleTokenManager_".concat(self.account.address.toString())
        self.AdminStoragePath = StoragePath(identifier: identifier.concat("_admin"))!
        self.AdminPublicPath = PublicPath(identifier: identifier.concat("_admin"))!

        // create the admin account
        let admin <- create Admin()
        self.account.storage.save(<-admin, to: self.AdminStoragePath)
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&Admin>(self.AdminStoragePath),
            at: self.AdminPublicPath
        )

        // Setup FungibleToken Shared FRC20TradingRecord
        self._ensureTradingRecordResourcesAvailable(self.account, tick: nil)

        emit ContractInitialized()
    }
}
