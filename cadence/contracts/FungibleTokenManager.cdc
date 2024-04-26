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
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20AccountsPool"
import "FRC20Agents"

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

    /** ------- Public Methods - Deploper ---- */

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
        let meta = FixesInscriptionFactory.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        assert(
            meta["op"] == "exec",
            message: "The inscription operation must be 'exec'"
        )
        let usage = meta["usage"] ?? panic("The token operation is not found")
        assert(
            usage == "init-ft",
            message: "The inscription is not for initialize a Fungible Token account"
        )

        let tick = meta["tick"] ?? panic("The token symbol is not found")
        assert(
            tick[0] == "$",
            message: "The token symbol must start with '$'"
        )

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

        self._enableAndCreateFixesFungibleTokenAccount(tick, newAccount: newAccount)

        // emit the event
        emit FungibleTokenAccountCreated(
            ticker: tick,
            account: newAddr,
            by: callerAddr
        )
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

        let tick = meta["tick"]?.toLower() ?? panic("The token tick is not found")

        /// Check if the account is already enabled
        assert(
            acctsPool.getFTContractAddress(tick) == nil,
            message: "The Fungible Token account is already created"
        )

        // Get the caller address
        let callerAddr = ins.owner!.address

        // Check if the the caller is valid
        let tokenMeta = frc20Indexer.getTokenMeta(tick: tick) ?? panic("The token is not registered")
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

        let newAddr = newAccount.address

        self._enableAndCreateFRC20FungibleTokenAccount(tick, newAccount: newAccount)

        // emit the event
        emit FungibleTokenAccountCreated(
            ticker: tick,
            account: newAddr,
            by: callerAddr
        )
    }

    /** ---- Internal Methods ---- */

    /// Create a new account to deploy the Fixes Fungible Token
    ///
    access(contract)
    fun _enableAndCreateFixesFungibleTokenAccount(
        _ tick: String,
        newAccount: Capability<&AuthAccount>,
    ) {
        // singleton resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // create the account for the fungible token at the accounts pool
        acctsPool.setupNewChildForFungibleToken(tick: tick, newAccount)

        // update the resources in the account
        self._ensureFungibleTokenAccountResourcesAvailable(tick, false)
        // deploy the contract of Fixes Fungible Token to the account
        self._updateFungibleTokenContractInAccount(tick, contractName: "FixesFungibleToken")
    }

    /// Create a new account to deploy the FRC20 Fungible Token
    ///
    access(contract)
    fun _enableAndCreateFRC20FungibleTokenAccount(
        _ tick: String,
        newAccount: Capability<&AuthAccount>,
    ) {
        // singleton resources
        let frc20Indexer = FRC20Indexer.getIndexer()
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // Check if the token is already registered
        let tickerName = tick.toLower()
        let tokenMeta = frc20Indexer.getTokenMeta(tick: tickerName) ?? panic("The token is not registered")

        // create the account for the fungible token at the accounts pool
        acctsPool.setupNewChildForFungibleToken(
            tick: tokenMeta.tick,
            newAccount
        )

        // update the resources in the account
        self._ensureFungibleTokenAccountResourcesAvailable(tickerName, true)
        // deploy the contract of FRC20 Fungible Token to the account
        self._updateFungibleTokenContractInAccount(tickerName, contractName: "FRC20FungibleToken")
    }

    /// Ensure all resources are available
    ///
    access(contract)
    fun _ensureFungibleTokenAccountResourcesAvailable(_ tick: String, _ withFRC20Agents: Bool) {
        // singleton resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick)
            ?? panic("The staking account was not created")
        let childAddr = childAcctRef.address

        var isUpdated = false
        // The staking pool should have the following resources in the account:
        // - FRC20FTShared.SharedStore: configuration
        //    - Store the Symbol, Name for the token
        // - FRC20Agents.IndexerController: Optional, the controller for the FRC20 Agents

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
        if withFRC20Agents {
            // Create the FRC20Agents.IndexerController and save it in the account
            let ctrlStoragePath = FRC20Agents.getIndexerControllerStoragePath()
            if childAcctRef.borrow<&AnyResource>(from: ctrlStoragePath) == nil {
                let indexerController <- FRC20Agents.createIndexerController([tick])
                childAcctRef.save(<- indexerController, to: ctrlStoragePath)

                isUpdated = true || isUpdated
            }
        }

        if isUpdated {
            emit FungibleTokenAccountResourcesUpdated(ticker: tick, account: childAddr)
        }
    }

    /// Update the FRC20 Fungible Token contract in the account
    ///
    access(contract)
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
