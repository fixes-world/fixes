/**
> Author: FIXeS World <https://fixes.world/>

# FRC20 Fungible Token Manager

This contract is used to manage the account and contract of Fixes' Fungible Tokens

*/
// Third Party Imports
import "FungibleToken"
import "FlowToken"
// Fixes imports
import "Fixes"
import "FixesInscriptionFactory"
import "FixesHeartbeat"
import "FixesFungibleTokenInterface"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20AccountsPool"
import "FRC20Agents"
import "FRC20TradingRecord"
import "FixesTradablePool"

/// The Manager contract for Fungible Token
///
access(all) contract FungibleTokenManager {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()
    /// Event emitted when a new Fungible Token Account is created
    access(all) event FungibleTokenAccountCreated(
        ticker: String,
        account: Address,
        by: Address
    )
    /// Event emitted when the resources of a Fungible Token Account are updated
    access(all) event FungibleTokenAccountResourcesUpdated(
        ticker: String,
        account: Address,
    )
    /// Event emitted when the contract of FRC20 Fungible Token is updated
    access(all) event FungibleTokenContractUpdated(
        ticker: String,
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
        access(all) view
        fun getFungibleTokens(): [String]
        /// get the address of the fungible token account
        access(all) view
        fun getFungibleTokenAccount(tick: String): Address?
    }

    /// Admin Resource, represents an admin resource and store in admin's account
    ///
    access(all) resource Admin: AdminPublic {

        // ---- Public Methods ----

        /// get the list of initialized fungible tokens
        ///
        access(all) view
        fun getFungibleTokens(): [String] {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            let dict = acctsPool.getFRC20Addresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
            return dict.keys
        }

        /// get the address of the fungible token account
        access(all) view
        fun getFungibleTokenAccount(tick: String): Address? {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            return acctsPool.getFTContractAddress(tick)
        }

        // ---- Developer Methods ----

        /// update all children contracts
        access(all)
        fun updateAllChildrenContracts() {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            let dict = acctsPool.getFRC20Addresses(type: FRC20AccountsPool.ChildAccountType.FungibleToken)
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
    }

    /** ------- Public Methods - Authorized Users ---- */

    /// Check if the Fungible Token Symbol is already enabled
    ///
    access(all)
    view fun isTokenSymbolEnabled(tick: String): Bool {
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        return acctsPool.getFTContractAddress(tick) != nil
    }

    /// Enable the Fixes Fungible Token
    ///
    access(all)
    fun initializeFixesFungibleTokenAccount(
        ins: &Fixes.Inscription,
        newAccount: Capability<&AuthAccount>,
    ) {
        // singletoken resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = self.verifyExecutingInscription(ins: ins, usage: "init-ft")
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
        self._ensureFungibleTokenAccountResourcesAvailable(tick, false)
        // deploy the contract of Fixes Fungible Token to the account
        self._updateFungibleTokenContractInAccount(tick, contractName: "FixesFungibleToken")

        // set the authorized account
        let tokenAdminRef = self.borrowWritableTokenAdmin(tick: tick)
        tokenAdminRef.updateAuthorizedUsers(callerAddr, true)

        // emit the event
        emit FungibleTokenAccountCreated(
            ticker: tick,
            account: newAddr,
            by: callerAddr
        )
    }

    /// Setup Tradable Pool Resources
    ///
    access(all)
    fun setupTradablePoolResources(
        ins: &Fixes.Inscription
    ) {
        // singletoken resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = self.verifyExecutingInscription(ins: ins, usage: "setup-tradable-pool")
        let tick = meta["tick"] ?? panic("The token symbol is not found")

        // Get the caller address
        let callerAddr = ins.owner!.address

        // get the token admin reference
        let tokenAdminRef = self.borrowWritableTokenAdmin(tick: tick)
        // check if the caller is authorized
        assert(
            tokenAdminRef.isAuthorizedUser(callerAddr),
            message: "You are not authorized to setup the tradable pool resources"
        )

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick)
            ?? panic("The staking account was not created")
        let childAddr = childAcctRef.address

        var isUpdated = false
        // - Add Tradable Pool Resource
        //   - Add Heartbeat Hook
        //   - Relink Flow Token Resource

        // add tradable pool resource
        let poolStoragePath = FixesTradablePool.getLiquidityPoolStoragePath()
        // if childAcctRef.borrow<&AnyResource>(from: poolStoragePath) == nil {
        //     let tradablePool <- FixesTradablePool.createTradableLiquidityPool(
        //         ins: ins,
        //         minterCap
        //     )
        // }
    }

    /// Verify the inscription for executing the Fungible Token
    ///
    access(self)
    fun verifyExecutingInscription(
        ins: &Fixes.Inscription,
        usage: String
    ): {String: String} {
        // inscription data
        let meta = FixesInscriptionFactory.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
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

    /// Enable the FRC20 Fungible Token
    ///
    access(all)
    fun initializeFRC20FungibleTokenAccount(
        ins: &Fixes.Inscription,
        newAccount: Capability<&AuthAccount>,
    ) {
        // singletoken resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // inscription data
        let meta = FixesInscriptionFactory.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        let op = meta["op"]?.toLower() ?? panic("The token operation is not found")
        assert(
            op == "init-ft",
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
        self._ensureFungibleTokenAccountResourcesAvailable(tickerName, true)
        // deploy the contract of FRC20 Fungible Token to the account
        self._updateFungibleTokenContractInAccount(tickerName, contractName: "FRC20FungibleToken")

        // emit the event
        emit FungibleTokenAccountCreated(
            ticker: tickerName,
            account: newAddr,
            by: callerAddr
        )
    }

    /** ---- Internal Methods ---- */

    /// Borrow the Fixes Fungible Token contract interface
    ///
    access(self)
    view fun borrowFixesFTContract(tick: String): &FixesFungibleTokenInterface {
        // try to borrow the account to check if it was created
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick)
            ?? panic("The staking account was not created")
        let contractRef = childAcctRef.contracts.borrow<&FixesFungibleTokenInterface>(name: "FixesFungibleToken")
            ?? panic("The Fixes Fungible Token contract was not deployed")
        return contractRef
    }

    /// Borrow the Fixes Fungible Token Admin Resource
    ///
    access(self)
    view fun borrowWritableTokenAdmin(tick: String): &AnyResource{FixesFungibleTokenInterface.IGlobalPublic, FixesFungibleTokenInterface.IAdminWritable} {
        // try to borrow the account to check if it was created
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick)
            ?? panic("The staking account was not created")
        let contractRef = childAcctRef.contracts.borrow<&FixesFungibleTokenInterface>(name: "FixesFungibleToken")
            ?? panic("The Fixes Fungible Token contract was not deployed")

        // Check if the admin resource is available
        let adminStoragePath = contractRef.getAdminStoragePath()
        return childAcctRef.borrow<&{FixesFungibleTokenInterface.IGlobalPublic, FixesFungibleTokenInterface.IAdminWritable}>(from: adminStoragePath)
            ?? panic("The admin resource is not available")
    }

    /// Ensure all resources are available
    ///
    access(self)
    fun _ensureFungibleTokenAccountResourcesAvailable(_ tick: String, _ isFRC20Token: Bool) {
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
        // - FRC20Agents.IndexerController: Optional, the controller for the FRC20 Agents
        // - FRC20FTShared.Hooks
        //   - TradingRecord

        // create the shared store and save it in the account
        if childAcctRef.borrow<&AnyResource>(from: FRC20FTShared.SharedStoreStoragePath) == nil {
            let sharedStore <- FRC20FTShared.createSharedStore()
            childAcctRef.save(<- sharedStore, to: FRC20FTShared.SharedStoreStoragePath)

            // link the shared store to the public path
            childAcctRef.unlink(FRC20FTShared.SharedStorePublicPath)
            childAcctRef.link<&FRC20FTShared.SharedStore{FRC20FTShared.SharedStorePublic}>(FRC20FTShared.SharedStorePublicPath, target: FRC20FTShared.SharedStoreStoragePath)

            isUpdated = true || isUpdated
        }

        let store = FRC20FTShared.borrowStoreRef(childAddr)
            ?? panic("The shared store was not created")
        if store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol) == nil {
            // ensure the symbol is without the '$' sign
            var symbol = tick
            if symbol[0] == "$" {
                symbol = symbol.slice(from: 1, upTo: symbol.length)
            }
            // set the symbol
            store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol, value: symbol)

            isUpdated = true || isUpdated
        }

        // Check if the FRC20Agents.IndexerController is required
        if isFRC20Token {
            // Create the FRC20Agents.IndexerController and save it in the account
            let ctrlStoragePath = FRC20Agents.getIndexerControllerStoragePath()
            if childAcctRef.borrow<&AnyResource>(from: ctrlStoragePath) == nil {
                let indexerController <- FRC20Agents.createIndexerController([tick])
                childAcctRef.save(<- indexerController, to: ctrlStoragePath)

                isUpdated = true || isUpdated
            }
        }

        // create the hooks and save it in the account
        if childAcctRef.borrow<&AnyResource>(from: FRC20FTShared.TransactionHookStoragePath) == nil {
            let hooks <- FRC20FTShared.createHooks()
            childAcctRef.save(<- hooks, to: FRC20FTShared.TransactionHookStoragePath)

            isUpdated = true || isUpdated
        }
        // link the hooks to the public path
        if childAcctRef
            .getCapability<&FRC20FTShared.Hooks{FRC20FTShared.TransactionHook, FixesHeartbeat.IHeartbeatHook}>(FRC20FTShared.TransactionHookPublicPath)
            .borrow() == nil {
            // link the hooks to the public path
            childAcctRef.unlink(FRC20FTShared.TransactionHookPublicPath)
            childAcctRef.link<&FRC20FTShared.Hooks{FRC20FTShared.TransactionHook, FixesHeartbeat.IHeartbeatHook}>(
                FRC20FTShared.TransactionHookPublicPath,
                target: FRC20FTShared.TransactionHookStoragePath
            )

            isUpdated = true || isUpdated
        }

        // ensure trading records are available
        if childAcctRef.borrow<&AnyResource>(from: FRC20TradingRecord.TradingRecordsStoragePath) == nil {
            let tradingRecords <- FRC20TradingRecord.createTradingRecords(tick)
            childAcctRef.save(<- tradingRecords, to: FRC20TradingRecord.TradingRecordsStoragePath)

            // link the trading records to the public path
            childAcctRef.unlink(FRC20TradingRecord.TradingRecordsPublicPath)
            childAcctRef.link<&FRC20TradingRecord.TradingRecords{FRC20TradingRecord.TradingRecordsPublic, FRC20TradingRecord.TradingStatusViewer, FRC20FTShared.TransactionHook}>(FRC20TradingRecord.TradingRecordsPublicPath, target: FRC20TradingRecord.TradingRecordsStoragePath)

            isUpdated = true || isUpdated
        }

        // borrow the hooks reference
        let hooksRef = childAcctRef.borrow<&FRC20FTShared.Hooks>(from: FRC20FTShared.TransactionHookStoragePath)
            ?? panic("The hooks were not created")

        // add the trading records to the hooks, if it is not added yet
        // get the public capability of the trading record hook
        let tradingRecordsCap = childAcctRef
            .getCapability<&FRC20TradingRecord.TradingRecords{FRC20TradingRecord.TradingRecordsPublic, FRC20TradingRecord.TradingStatusViewer, FRC20FTShared.TransactionHook}>(
                FRC20TradingRecord.TradingRecordsPublicPath
            )
        assert(tradingRecordsCap.check(), message: "The trading record hook is not valid")
        // get the reference of the trading record hook
        let recordsRef = tradingRecordsCap.borrow()
            ?? panic("The trading record hook is not valid")
        if !hooksRef.hasHook(recordsRef.getType()) {
            hooksRef.addHook(tradingRecordsCap)
        }

        if isUpdated {
            emit FungibleTokenAccountResourcesUpdated(ticker: tick, account: childAddr)
        }
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
            if childAcctRef.contracts.get(name: contractName) != nil {
                // update the contract
                // This method will update the contract, but it maybe deprecated in Cadence 1.0
                childAcctRef.contracts.update__experimental(name: contractName, code: ftContract.code)
                // childAcctRef.contracts.update(name: contractName, code: ftContract.code)
            } else {
                // add the contract
                childAcctRef.contracts.add(name: contractName, code: ftContract.code)
            }
        } else {
            panic("The contract of FRC20 Fungible Token is not deployed")
        }

        // emit the event
        emit FungibleTokenContractUpdated(ticker: tick, account: childAddr, contractName: contractName)
    }

    init() {
        let identifier = "FungibleTokenManager_".concat(self.account.address.toString())
        self.AdminStoragePath = StoragePath(identifier: identifier.concat("_admin"))!
        self.AdminPublicPath = PublicPath(identifier: identifier.concat("_admin"))!

        // create the admin account
        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)
        // @deprecated in Cadence 1.0
        self.account.link<&Admin{AdminPublic}>(self.AdminPublicPath, target: self.AdminStoragePath)

        emit ContractInitialized()
    }
}
