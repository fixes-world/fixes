/**
> Author: Fixes Lab <https://github.com/fixes-world/>

# EVMAgent

This contract is used to fetch the child account by verifying the signature of the EVM address.

*/
// Third-party Imports
import "FungibleToken"
import "FlowToken"
import "StringUtils"
// Fixes Imports
import "ETHUtils"
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20Staking"
import "FRC20AccountsPool"

access(all) contract EVMAgent {

    access(all) entitlement Manage

    /* --- Events --- */

    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /// Event emitted when a new agency is setup
    access(all) event NewAgencySetup(agency: Address)
    /// Event emitted when a new agency manager is created
    access(all) event NewAgencyManagerCreated(forAgency: Address)
    /// Event emitted when a new entrusted account is created.
    access(all) event NewEntrustedAccountCreated(
        accountKey: String,
        evmAddress: String,
        entrustedAccount: Address,
        byAgency: Address,
        initialFunding: UFix64,
    )
    /// Event emitted when the entrusted account is verified
    access(all) event EntrustedAccountVerified(
        accountKey: String,
        evmAddress: String,
        entrustedAccount: Address,
        byAgency: Address,
        message: String,
        fee: UFix64,
    )

    /* --- Variable, Enums and Structs --- */

    access(all)
    let entrustedStatusStoragePath: StoragePath
    access(all)
    let entrustedStatusPublicPath: PublicPath
    access(all)
    let evmAgencyManagerStoragePath: StoragePath
    access(all)
    let evmAgencyStoragePath: StoragePath
    access(all)
    let evmAgencyPublicPath: PublicPath
    access(all)
    let evmAgencyCenterStoragePath: StoragePath
    access(all)
    let evmAgencyCenterPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    access(all) resource interface  IEntrustedStatus {
        access(all)
        let key: String

        /// Borrow the agency capability
        access(all)
        view fun borrowAgency(): &Agency
        /// Get the flow spent by the entrusted account
        access(all)
        view fun getFeeSpent(): UFix64
        /// Add the spent flow fee
        access(contract)
        fun addSpentFlowFee(_ amount: UFix64)
    }

    /// Entrusted status resource stored in the entrusted child account
    ///
    access(all) resource EntrustedStatus: IEntrustedStatus {
        access(all) let key: String
        // Capability to the agency
        access(self) let agency: Capability<&Agency>
        // record the flow spent by the entrusted account
        access(self) var feeSpent: UFix64

        init(
            key: String,
            _ agency: Capability<&Agency>
        ) {
            self.key = key
            self.agency = agency
            self.feeSpent = 0.0
        }

        /// Borrow the agency capability
        access(all)
        view fun borrowAgency(): &Agency {
            return self.agency.borrow() ?? panic("Agency not found")
        }

        /// Get the flow spent by the entrusted account
        access(all)
        view fun getFeeSpent(): UFix64 {
            return self.feeSpent
        }

        /// Add the spent flow fee
        access(contract)
        fun addSpentFlowFee(_ amount: UFix64) {
            self.feeSpent = self.feeSpent + amount
        }
    }

    /// Agency manager resource
    ///
    access(all) resource AgencyManager {
        // Capability to the agency
        access(self)
        let agency: Capability<auth(Manage) &Agency>

        init(
            _ agency: Capability<auth(Manage) &Agency>
        ) {
            self.agency = agency
        }

        /// Borrow the agency capability
        access(Manage)
        fun borrowAgency(): auth(Manage) &Agency {
            return self.agency.borrow() ?? panic("Agency not found")
        }

        /// Withdraw the flow from the agency
        ///
        access(Manage)
        fun withdraw(amt: UFix64): @FlowToken.Vault {
            let agency = self.borrowAgency()
            assert(
                agency.getFlowBalance() >= amt,
                message: "Insufficient balance"
            )
            return <- agency.withdraw(amt: amt)
        }
    }

    /// Agency status
    ///
    access(all) struct AgencyStatus {
        access(all) let extra: {String: AnyStruct}
        access(all) var managingEntrustedAccounts: UInt64
        access(all) var spentFlowAmount: UFix64
        access(all) var earnedFlowAmount: UFix64

        init() {
            self.extra = {}
            self.managingEntrustedAccounts = 0
            self.spentFlowAmount = 0.0
            self.earnedFlowAmount = 0.0
        }

        access(contract)
        fun addSpentFlowAmount(_ amount: UFix64) {
            self.spentFlowAmount = self.spentFlowAmount + amount
        }

        access(contract)
        fun addEarnedFlowAmount(_ amount: UFix64) {
            self.earnedFlowAmount = self.earnedFlowAmount + amount
        }

        access(contract)
        fun addManagingEntrustedAccounts(_ count: UInt64) {
            self.managingEntrustedAccounts = self.managingEntrustedAccounts + count
        }

        access(contract)
        fun updateExtra(_ key: String, _ value: AnyStruct) {
            self.extra[key] = value
        }
    }

    /// Public interface to the agency
    ///
    access(all) resource interface AgencyPublic {
        /// Get the owner address
        access(all)
        view fun getOwnerAddress(): Address {
            return self.owner?.address ?? panic("Agency should have an owner")
        }

        /// Get the agency account
        access(all)
        view fun getDetails(): AgencyStatus

        /// Get the balance of the flow for the agency
        access(all)
        view fun getFlowBalance(): UFix64

        // Check if the EVM address is managed by the agency
        access(all)
        view fun isEVMAccountManaged(_ evmAddress: String): Bool

        // Check if the social id is managed by the agency
        access(all)
        view fun isSocialIDManaged(_ platform: String, _ platformId: String): Bool

        /// Get the account key of the entrusted account
        access(all)
        view fun getAccountKey(_ evmAddress: String): String

        /// The agency will fund the new created entrusted account with 0.01 $FLOW
        access(all)
        fun createSocialEntrustedAccount(
            platform: String,
            platformId: String,
            hexPublicKey: String,
            hexSignature: String,
            timestamp: UInt64,
            _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>
        ): @FlowToken.Vault

        /// Create a new entrusted account by the agency
        access(all)
        fun createEntrustedAccount(
            hexPublicKey: String,
            hexSignature: String,
            timestamp: UInt64,
            _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>
        ): @FlowToken.Vault

        /// Verify the evm signature, if valid, borrow the reference of the entrusted account
        ///
        access(all)
        fun verifyAndBorrowEntrustedAccount(
            methodFingerprint: String,
            params: [String],
            hexPublicKey: String,
            hexSignature: String,
            timestamp: UInt64,
        ): auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account
    }

    /// Private interface to the agency
    ///
    access(all) resource interface AgencyPrivate  {
        /// Create a new agency manager
        access(Manage)
        fun createAgencyManager(): @AgencyManager

        /// Withdraw the flow from the agency
        access(Manage)
        fun withdraw(amt: UFix64): @FlowToken.Vault
    }

    /// Agency resource
    ///
    access(all) resource Agency: AgencyPublic, AgencyPrivate {
        access(all) let creator: Address
        /// Current status of the agency
        access(self)
        let status: AgencyStatus
        /// Key => Address
        /// Keys format:
        ///     EVMAddress => 0xabc...123
        ///     SoicalHandleKey => platform:platformId
        access(self)
        let managedEntrustedAccounts: {String: Address}

        init(
            _ creatingIns: &Fixes.Inscription
        ) {
            self.creator = creatingIns.owner?.address ?? panic("Agency should have an owner")
            self.managedEntrustedAccounts = {}
            self.status = AgencyStatus()
        }

        /// Setup the agency
        access(Manage)
        fun setup(
            _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>
        ) {
            pre {
                self.getOwnerAddress() == acctCap.address: "Only the owner can setup the agency"
            }
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()

            let creator = self.creator.toString()
            assert(
                acctsPool.getEVMAgencyAddress(creator) == nil,
                message: "Agency already registered"
            )

            acctsPool.setupNewChildForEVMAgency(owner: creator, acctCap)

            // get the agency account
            let authAcct = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.EVMAgency, creator)
                ?? panic("Agency account not found")

            // linking capability
            if authAcct.capabilities.get<&Agency>(EVMAgent.evmAgencyPublicPath) != nil {
                authAcct.capabilities.unpublish(EVMAgent.evmAgencyPublicPath)
                authAcct.capabilities.publish(
                    authAcct.capabilities.storage.issue<&Agency>(EVMAgent.evmAgencyStoragePath),
                    at: EVMAgent.evmAgencyPublicPath
                )
            }

            // emit event
            emit NewAgencySetup(agency: authAcct.address)
        }

        /** ---- Private method ---- */

        access(Manage)
        fun createAgencyManager(): @AgencyManager {
            let cap = self._getSelfPrivCap()

            emit NewAgencyManagerCreated(forAgency: self.getOwnerAddress())

            return <- create AgencyManager(cap)
        }


        /// Withdraw the flow from the agency
        ///
        access(Manage)
        fun withdraw(amt: UFix64): @FlowToken.Vault {
            let acct = self._borrowAgencyAccount()
            let flowVaultRef = acct.storage
                .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("The flow vault is not found")
            assert(
                flowVaultRef.balance >= amt,
                message: "Insufficient balance"
            )
            let vault <- flowVaultRef.withdraw(amount: amt)
            return <- (vault as! @FlowToken.Vault)
        }

        /* --- Public methods  --- */

        // Check if the EVM address is managed by the agency
        access(all)
        view fun isEVMAccountManaged(_ evmAddress: String): Bool {
            return self.managedEntrustedAccounts[evmAddress] != nil
        }

        // Check if the social id is managed by the agency
        access(all)
        view fun isSocialIDManaged(_ platform: String, _ platformId: String): Bool {
            let id = platform.concat(":").concat(platformId)
            return self.managedEntrustedAccounts[id] != nil
        }

        /// Get the account key of the entrusted account
        access(all)
        view fun getAccountKey(_ evmAddress: String): String {
            let cacheKey = "AccountKey:".concat(evmAddress)
            if let accountKey = self.status.extra[cacheKey] as! String? {
                return accountKey
            }
            return evmAddress
        }

        /// Get the agency account
        access(all)
        view fun getDetails(): AgencyStatus {
            return self.status
        }

        /// Get the balance of the flow for the agency
        access(all)
        view fun getFlowBalance(): UFix64 {
            if let ref = getAccount(self.getOwnerAddress())
                .capabilities.get<&{FungibleToken.Balance}>(/public/flowTokenBalance)
                .borrow() {
                return ref.balance
            }
            return 0.0
        }

        /// The agency will fund the new created entrusted account with 0.01 $FLOW
        ///
        access(all)
        fun createSocialEntrustedAccount(
            platform: String,
            platformId: String,
            hexPublicKey: String,
            hexSignature: String,
            timestamp: UInt64,
            _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>
        ): @FlowToken.Vault {
            let socialId = EVMAgent.getSocialId(platform, platformId)

            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            // Ensure the key is not already registered
            let existingAddr = acctsPool.getEntrustedAccountAddress(socialId)
            assert(
                existingAddr == nil,
                message: "Already registered in account pool, SocialID: ".concat(socialId)
            )
            assert(
                self.managedEntrustedAccounts[socialId] == nil,
                message: "Already registered for an agent account, SocialID: ".concat(socialId)
            )

            // Calculate the EVM address from the public key
            let evmAddress = ETHUtils.getETHAddressFromPublicKey(hexPublicKey: hexPublicKey)

            let message = "op=create-entrusted-account-by-social(String|String)"
                .concat(",params=").concat(platform).concat("|").concat(platformId)
                .concat(",address=").concat(evmAddress)
                .concat(",timestamp=").concat(timestamp.toString())
            log("Verifying message: ".concat(message))
            let isValid = ETHUtils.verifySignature(hexPublicKey: hexPublicKey, hexSignature: hexSignature, message: message)
            assert(
                isValid,
                message: "Invalid signature"
            )

            return <- self._createEntrustedAccount(accountKey: socialId, evmAddress: evmAddress, acctCap)
        }

        /// The agency will fund the new created entrusted account with 0.01 $FLOW
        ///
        access(all)
        fun createEntrustedAccount(
            hexPublicKey: String,
            hexSignature: String,
            timestamp: UInt64,
            _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>
        ): @FlowToken.Vault {
            let evmAddress = ETHUtils.getETHAddressFromPublicKey(hexPublicKey: hexPublicKey)
            assert(
                self.managedEntrustedAccounts[evmAddress] == nil,
                message: "EVM address already registered for an agent account"
            )
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            // Ensure the evmAddress is not already registered
            let existingAddr = acctsPool.getEntrustedAccountAddress(evmAddress)
            assert(
                existingAddr == nil,
                message: "EVM address already registered for an agent account"
            )

            let message = "op=create-entrusted-account(),params="
                .concat(",address=").concat(evmAddress)
                .concat(",timestamp=").concat(timestamp.toString())
            log("Verifying message: ".concat(message))
            let isValid = ETHUtils.verifySignature(hexPublicKey: hexPublicKey, hexSignature: hexSignature, message: message)
            assert(
                isValid,
                message: "Invalid signature"
            )

            return <- self._createEntrustedAccount(accountKey: evmAddress, evmAddress: evmAddress, acctCap)
        }

        /// Create the entrusted account
        access(self)
        fun _createEntrustedAccount(
            accountKey: String,
            evmAddress: String,
            _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>
        ): @FlowToken.Vault {
            pre {
                acctCap.check(): "Invalid account capability"
            }
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            // Get the agency account
            let agencyAcct = self._borrowAgencyAccount()

            // Get the entrusted account
            let entrustedAcct = acctCap.borrow() ?? panic("Entrusted account not found")
            let entrustedAddress = entrustedAcct.address
            // Reference to the flow vault of the entrusted account
            let entrustedAcctFlowBalanceRef = entrustedAcct
                .capabilities.get<&{FungibleToken.Balance}>(/public/flowTokenBalance)
                .borrow()
                ?? panic("Could not borrow Balance reference to the Vault")
            // Reference to the recipient's receiver
            let entrustedAcctFlowRecipientRef = entrustedAcct
                .capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow()
                ?? panic("Could not borrow receiver reference to the recipient's Vault")

            // Get the flow vault from the agency account
            let flowVaultRef = agencyAcct.storage
                .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("The flow vault is not found")
            let spentFlowAmt = EVMAgent.getAgencyFlowFee()
            // Withdraw 0.01 $FLOW from agency and deposit to the new account
            let initFlow <- flowVaultRef.withdraw(amount: spentFlowAmt)
            // Subtract the original amount from the entrusted account, to ensure the account is not overfunded
            let refundBalance <- initFlow.withdraw(amount: entrustedAcctFlowBalanceRef.balance)

            // Deposit the init balance to the entrusted account
            entrustedAcctFlowRecipientRef.deposit(from: <-initFlow)

            // add the cap to accounts pool
            acctsPool.setupNewChildForEntrustedAccount(key: accountKey, acctCap)

            // Ensure all resources in initialized to the entrusted account
            self._ensureEntrustedAcctResources(accountKey)
            self.status.addManagingEntrustedAccounts(1)
            self.status.addSpentFlowAmount(spentFlowAmt)

            /// Save the entrusted account address
            self.managedEntrustedAccounts[accountKey] = entrustedAddress
            /// update the status
            if accountKey != evmAddress {
                let cacheKey = "AccountKey:".concat(evmAddress)
                self.status.updateExtra(cacheKey, accountKey)
            }

            // emit event
            emit NewEntrustedAccountCreated(
                accountKey: accountKey,
                evmAddress: evmAddress,
                entrustedAccount: entrustedAddress,
                byAgency: agencyAcct.address,
                initialFunding: spentFlowAmt
            )

            // return the refund balance
            return <- (refundBalance as! @FlowToken.Vault)
        }

        /// Verify the evm signature, if valid, borrow the reference of the entrusted account
        /// - parameter methodFingerprint: The method fingerprint
        /// - parameter params: The parameters for the method
        ///
        access(all)
        fun verifyAndBorrowEntrustedAccount(
            methodFingerprint: String,
            params: [String],
            hexPublicKey: String,
            hexSignature: String,
            timestamp: UInt64
        ): auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account {
            let message = "op=".concat(methodFingerprint)
                .concat(",params=").concat(params.length > 0 ? StringUtils.join(params, "|") : "")
            return self._verifyAndBorrowEntrustedAccount(
                message: message,
                hexPublicKey: hexPublicKey,
                hexSignature: hexSignature,
                timestamp: timestamp
            )
        }

        /// Verify the evm signature, if valid, borrow the reference of the entrusted account
        ///
        access(self)
        fun _verifyAndBorrowEntrustedAccount(
            message: String,
            hexPublicKey: String,
            hexSignature: String,
            timestamp: UInt64
        ): auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account {
            let evmAddress = ETHUtils.getETHAddressFromPublicKey(hexPublicKey: hexPublicKey)
            let accountKey = self.getAccountKey(evmAddress)
            assert(
                self.managedEntrustedAccounts[accountKey] != nil,
                message: "EVM address not registered for an agent account"
            )
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()

            // Ensure the account is already registered
            let entrustedAddr = acctsPool.getEntrustedAccountAddress(accountKey)
            assert(
                entrustedAddr != nil,
                message: "EVM address not registered for an agent account"
            )

            let msgToVerify = message
                .concat(",address=").concat(evmAddress)
                .concat(",timestamp=").concat(timestamp.toString())

            let isValid = ETHUtils.verifySignature(
                hexPublicKey: hexPublicKey,
                hexSignature: hexSignature,
                message: msgToVerify
            )
            assert(isValid, message: "Invalid signature")

            // Since the signature is valid, we think the transaction is valid
            // and we can borrow the reference to the entrusted account
            let entrustedAcct = acctsPool.borrowChildAccount(
                type: FRC20AccountsPool.ChildAccountType.EVMEntrustedAccount,
                accountKey
            ) ?? panic("The staking account was not created")

            // The entrusted account need to pay a fee to the agency
            let entrustedAcctFlowVauleRef = entrustedAcct
                .storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("The flow vault is not found")

            let agencyFlowReceiptRef = self._borrowAgencyAccount()
                .capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow()
                ?? panic("Could not borrow receiver reference to the recipient's Vault")

            let fee = EVMAgent.getAgencyFlowFee()
            agencyFlowReceiptRef.deposit(from: <- entrustedAcctFlowVauleRef.withdraw(amount: fee))

            // update the status
            self.status.addEarnedFlowAmount(fee)
            // update the entrusted account status
            if let entrustedStatus = entrustedAcct
                .storage.borrow<&EntrustedStatus>(from: EVMAgent.entrustedStatusStoragePath) {
                entrustedStatus.addSpentFlowFee(fee)
            }

            // emit event
            emit EntrustedAccountVerified(
                accountKey: accountKey,
                evmAddress: evmAddress,
                entrustedAccount: entrustedAcct.address,
                byAgency: self.getOwnerAddress(),
                message: message,
                fee: fee
            )

            return entrustedAcct
        }

        /* --- Contract access methods  --- */

        /// Ensure the resources are initialized to the entrusted account
        ///
        access(contract)
        fun _ensureEntrustedAcctResources(_ key: String): Bool {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
                // try to borrow the account to check if it was created
            let childAcctRef = acctsPool.borrowChildAccount(type: FRC20AccountsPool.ChildAccountType.EVMEntrustedAccount, key)
                ?? panic("The staking account was not created")

            var isUpdated = false
            // The entrust account should have the following resources in the account:
            // - EVMAgent.EntrustedStatus

            // create the shared store and save it in the account
            if childAcctRef.storage.borrow<&AnyResource>(from: EVMAgent.entrustedStatusStoragePath) == nil {
                let cap = EVMAgent.getAgencyPublicCap(self.getOwnerAddress())
                assert(cap.check(), message: "Invalid agency capability")

                let sharedStore <- create EVMAgent.EntrustedStatus(key: key, cap)
                childAcctRef.storage.save(<- sharedStore, to: EVMAgent.entrustedStatusStoragePath)

                // link the shared store to the public path
                childAcctRef.capabilities.unpublish(EVMAgent.entrustedStatusPublicPath)
                childAcctRef.capabilities.publish(
                    childAcctRef.capabilities.storage.issue<&EVMAgent.EntrustedStatus>(EVMAgent.entrustedStatusStoragePath),
                    at: EVMAgent.entrustedStatusPublicPath
                )

                isUpdated = true || isUpdated
            }

            return isUpdated
        }

        /* --- Internal access methods  --- */

        /// Get the private capability of the agency
        ///
        access(self)
        fun _getSelfPrivCap(): Capability<auth(Manage) &Agency> {
            // get the agency account
            let authAcct = self._borrowAgencyAccount()

            return authAcct.capabilities.storage.issue<auth(Manage) &Agency>(EVMAgent.evmAgencyStoragePath)
        }

        access(self)
        fun _borrowAgencyAccount(): auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            return acctsPool.borrowChildAccount(
                type: FRC20AccountsPool.ChildAccountType.EVMAgency,
                self.creator.toString()
            ) ?? panic("Agency account not found")
        }
    }

    /// Agency center public interface
    ///
    access(all) resource interface AgencyCenterPublic {
        /// Get the agencies
        access(all)
        view fun getAgencies(): [Address]

        /// Create a new agency
        access(all)
        fun createAgency(
            ins: auth(Fixes.Extractable) &Fixes.Inscription,
            _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>
        ): @AgencyManager

        /// Get the agency by evm address
        access(all)
        view fun borrowAgencyByEVMAddress(_ evmAddress: String): &Agency?
        /// Get the agency by address
        access(all)
        fun pickValidAgency(): &Agency?
    }

    /// Agency center resource
    ///
    access(all) resource AgencyCenter: AgencyCenterPublic {
        access(self)
        let agencies: {Address: Bool}

        init() {
            self.agencies = {}
        }

        /// Get the agencies
        ///
        access(all)
        view fun getAgencies(): [Address] {
            return self.agencies.keys
        }

        /// Create a new agency
        ///
        access(all)
        fun createAgency(
            ins: auth(Fixes.Extractable) &Fixes.Inscription,
            _ acctCap: Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>
        ): @AgencyManager {
            // singleton resources
            let acctPool = FRC20AccountsPool.borrowAccountsPool()
            let frc20Indexer = FRC20Indexer.getIndexer()

            // inscription data
            let meta = FixesInscriptionFactory.parseMetadata(ins.borrowData())
            let op = meta["op"]?.toLower() ?? panic("The token operation is not found")
            assert(
                op == "create-evm-agency" || op == "create-acct-agency",
                message: "Invalid operation"
            )
            let fromAddr = ins.owner?.address ?? panic("The owner address is not found")

            let delegator = FRC20Staking.borrowDelegator(fromAddr)
                ?? panic("The delegator is not found")
            let platformStakeTick = FRC20FTShared.getPlatformStakingTickerName()
            let stakedBalance = delegator.getStakedBalance(tick: platformStakeTick)
            // only the delegator with enough staked balance can create the agency
            assert(
                stakedBalance >= 10000.0,
                message: "The delegator should have staked enough balance"
            )

            // ensure the inscription owner is valid delegator in the FRC20StakingPool
            let agency <- create Agency(ins)

            // setup the agency
            let acct = acctCap.borrow() ?? panic("Invalid account capability")
            let addr = acct.address

            // extract the flow from the inscriptions and deposit to the agency
            let flowReceiverRef = Fixes.borrowFlowTokenReceiver(addr)
                ?? panic("Could not borrow receiver reference to the recipient's Vault")
            flowReceiverRef.deposit(from: <- ins.extract())

            // save the agency
            acct.storage.save(<- agency, to: EVMAgent.evmAgencyStoragePath)

            let agencyRef = acct.storage
                .borrow<auth(Manage) &Agency>(from: EVMAgent.evmAgencyStoragePath)
                ?? panic("Agency not found")
            agencyRef.setup(acctCap)
            // agency registered
            self.agencies[addr] = true

            // create a new agency manager
            return <- agencyRef.createAgencyManager()
        }

        /// Get the agency by evm address
        ///
        access(all)
        view fun borrowAgencyByEVMAddress(_ evmAddress: String): &Agency? {
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            if let addr = acctsPool.getEntrustedAccountAddress(evmAddress) {
                if let entrustStatus = EVMAgent.borrowEntrustStatus(addr) {
                    return entrustStatus.borrowAgency()
                }
            } else {
                let allAgencies = self.getAgencies()
                for addr in allAgencies {
                    if let agency = EVMAgent.borrowAgency(addr) {
                        let acctKey = agency.getAccountKey(evmAddress)
                        if agency.isEVMAccountManaged(acctKey) {
                            return agency
                        }
                    }
                }
            }
            return nil
        }

        /// Get the agency by address
        access(all)
        fun pickValidAgency(): &Agency? {
            let keys = self.agencies.keys
            if keys.length == 0 {
                return nil
            }

            let filteredAddrs: [Address] = []
            for addr in keys {
                // get flow balance of the agency
                if let flowVaultRef = getAccount(addr)
                    .capabilities.get<&{FungibleToken.Balance}>(/public/flowTokenBalance)
                    .borrow() {
                    // only the agency with enough balance can be picked
                    if flowVaultRef.balance >= 0.1 {
                        filteredAddrs.append(addr)
                    }
                }
            }
            if filteredAddrs.length == 0 {
                return nil
            }

            let index = revertibleRandom<UInt64>(modulo: UInt64(filteredAddrs.length))
            // borrow the agency
            return EVMAgent.borrowAgency(filteredAddrs[index])
        }
    }

    /* --- Public methods  --- */

    access(all)
    view fun getIdentifierPrefix(): String {
        return "EVMAgency_".concat(self.account.address.toString())
    }

    /// Get the fee for any operation by the agency
    ///
    access(all)
    view fun getAgencyFlowFee(): UFix64 {
        return 0.01
    }

    /// Get the social id by platform + id
    ///
    access(all)
    view fun getSocialId(_ platform: String, _ platformId: String): String {
        return platform.concat(":").concat(platformId)
    }

    /// Get the capability to the entrusted status
    ///
    access(all)
    view fun borrowEntrustStatus(_ addr: Address): &EntrustedStatus? {
        return getAccount(addr)
            .capabilities.get<&EntrustedStatus>(self.entrustedStatusPublicPath)
            .borrow()
    }

    /// Get the capability to the agency
    ///
    access(all)
    view fun getAgencyPublicCap(_ addr: Address): Capability<&Agency> {
        return getAccount(addr)
            .capabilities.get<&Agency>(self.evmAgencyPublicPath)
    }

    /// Borrow the reference to agency public
    ///
    access(all)
    view fun borrowAgency(_ addr: Address): &Agency? {
        return self.getAgencyPublicCap(addr).borrow()
    }

    /// Borrow the reference to agency public
    ///
    access(all)
    view fun borrowAgencyByEVMPublicKey(_ hexPubKey: String): &Agency? {
        let center = self.borrowAgencyCenter()
        let evmAddr = ETHUtils.getETHAddressFromPublicKey(hexPublicKey: hexPubKey)
        return center.borrowAgencyByEVMAddress(evmAddr)
    }

    /// Borrow the reference to agency center
    ///
    access(all)
    view fun borrowAgencyCenter(): &AgencyCenter {
        return getAccount(self.account.address)
            .capabilities.get<&AgencyCenter>(self.evmAgencyCenterPublicPath)
            .borrow() ?? panic("Agency center not found")
    }

    init() {
        let prefix = EVMAgent.getIdentifierPrefix()
        self.entrustedStatusStoragePath = StoragePath(identifier: prefix.concat("_entrusted_status"))!
        self.entrustedStatusPublicPath = PublicPath(identifier: prefix.concat("_entrusted_status"))!

        self.evmAgencyManagerStoragePath = StoragePath(identifier: prefix.concat("_agency_manager"))!

        self.evmAgencyStoragePath = StoragePath(identifier: prefix.concat("_agency"))!
        self.evmAgencyPublicPath = PublicPath(identifier: prefix.concat("_agency"))!

        self.evmAgencyCenterStoragePath = StoragePath(identifier: prefix.concat("_center"))!
        self.evmAgencyCenterPublicPath = PublicPath(identifier: prefix.concat("_center"))!

        // Save the agency center resource
        let center <- create AgencyCenter()
        self.account.storage.save(<- center, to: self.evmAgencyCenterStoragePath)
        // link the public path
        self.account.capabilities.publish(
            self.account.capabilities.storage.issue<&AgencyCenter>(self.evmAgencyCenterStoragePath),
            at: self.evmAgencyCenterPublicPath
        )

        emit ContractInitialized()
    }
}
