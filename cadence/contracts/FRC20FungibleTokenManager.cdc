/**
> Author: FIXeS World <https://fixes.world/>

# FRC20 Fungible Token Manager

This contract is used to manage the account and contract FRC20 Fungible Token

*/
// Third Party Imports
import "FungibleToken"
import "FlowToken"
// Fixes imports
import "Fixes"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20AccountsPool"
import "FRC20FungibleToken"

access(all) contract FRC20FungibleTokenManager {
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
            for tick in ticks {
                FRC20FungibleTokenManager._updateFungibleTokenContractInAccount(tick)
            }
        }
    }

    /** ------- Public Methods - Deploper ---- */

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
        let meta = frc20Indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
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

        self._enableAndCreateFungibleTokenAccount(tick, newAccount: newAccount)

        // emit the event
        emit FungibleTokenAccountCreated(
            ticker: tick,
            account: newAddr,
            by: callerAddr
        )
    }

    /** ---- Internal Methods ---- */

    /// Create a new account to deploy the FRC20 Fungible Token
    ///
    access(contract)
    fun _enableAndCreateFungibleTokenAccount(
        _ tick: String,
        newAccount: Capability<&AuthAccount>,
    ){
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
        self._ensureFungibleTokenAccountResourcesAvailable(tickerName)

        // deploy the contract of FRC20 Fungible Token to the account
        self._updateFungibleTokenContractInAccount(tickerName)
    }

    /// Ensure all resources are available
    ///
    access(contract)
    fun _ensureFungibleTokenAccountResourcesAvailable(_ tick: String) {
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
            store.setByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol, value: tick)

            isUpdated = true || isUpdated
        }

        if isUpdated {
            emit FungibleTokenAccountResourcesUpdated(ticker: tick, account: childAddr)
        }
    }

    /// Update the FRC20 Fungible Token contract in the account
    ///
    access(contract)
    fun _updateFungibleTokenContractInAccount(_ tick: String) {
        // singleton resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()

        // try to borrow the account to check if it was created
        let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.FungibleToken, tick)
            ?? panic("The staking account was not created")
        let childAddr = childAcctRef.address

        // Load contract from the account
        let contractName = "FRC20FungibleToken"
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

        emit FungibleTokenContractUpdated(ticker: tick, account: childAddr)
    }

    init() {
        let identifier = "FRC20FungibleTokenManager_".concat(self.account.address.toString())
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
