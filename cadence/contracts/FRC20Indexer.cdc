import "Fixes"
import "FlowToken"
import "StringUtils"

pub contract FRC20Indexer {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    pub event ContractInitialized()

    /// Event emitted when a FRC20 token is deployed
    pub event FRC20Deployed(tick: String, max: UFix64, limit: UFix64, deployer: Address)
    /// Event emitted when a FRC20 token is minted
    pub event FRC20Minted(tick: String, amount: UFix64, to: Address)
    /// Event emitted when the owner of an inscription is updated
    pub event FRC20Transfer(tick: String, from: Address, to: Address, amount: UFix64)
    /// Event emitted when a FRC20 token is burned
    pub event FRC20Burned(tick: String, amount: UFix64, from: Address, flowExtracted: UFix64)
    /// Event emitted when a FRC20 token is set to be burnable
    pub event FRC20BurnableSet(tick: String, burnable: Bool)
    /// Event emitted when a FRC20 token is burned unsupplied tokens
    pub event FRC20UnsuppliedBurned(tick: String, amount: UFix64)

    /* --- Variable, Enums and Structs --- */
    access(all)
    let IndexerStoragePath: StoragePath
    access(all)
    let IndexerPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    /// The meta-info of a FRC20 token
    pub struct FRC20Meta {
        access(all) let tick: String
        access(all) let max: UFix64
        access(all) let limit: UFix64
        access(all) let deployAt: UFix64
        access(all) let deployer: Address
        access(all) var burnable: Bool
        access(all) var supplied: UFix64
        access(all) var burned: UFix64

        init(
            tick: String,
            max: UFix64,
            limit: UFix64,
            deployAt: UFix64,
            deployer: Address,
            supplied: UFix64,
            burned: UFix64,
            burnable: Bool
        ) {
            self.tick = tick
            self.max = max
            self.limit = limit
            self.deployAt = deployAt
            self.deployer = deployer
            self.supplied = supplied
            self.burned = burned
            self.burnable = burnable
        }

        access(all)
        fun updateSupplied(_ amt: UFix64) {
            self.supplied = amt
        }

        access(all)
        fun updateBurned(_ amt: UFix64) {
            self.burned = amt
        }

        access(all)
        fun setBurnable(_ burnable: Bool) {
            self.burnable = burnable
        }
    }

    pub resource interface IndexerPublic {
        /* --- read-only --- */
        /// Get all the tokens
        access(all) view
        fun getTokens(): [String]
        /// Get the meta-info of a token
        access(all) view
        fun getTokenMeta(tick: String): FRC20Meta?
        /// Check if an inscription is a valid FRC20 inscription
        access(all) view
        fun isValidFRC20Inscription(ins: &Fixes.Inscription): Bool
        /// Get the balance of a FRC20 token
        access(all) view
        fun getBalance(tick: String, addr: Address): UFix64
        /// Get all balances of some address
        access(all) view
        fun getBalances(addr: Address): {String: UFix64}
        /// Get the holders of a FRC20 token
        access(all) view
        fun getHolders(tick: String): [Address]
        /// Get the amount of holders of a FRC20 token
        access(all) view
        fun getHoldersAmount(tick: String): UInt64
        /// Get the pool balance of a FRC20 token
        access(all) view
        fun getPoolBalance(tick: String): UFix64
        /* --- write --- */
        /// Deploy a new FRC20 token
        access(all)
        fun deploy(ins: &Fixes.Inscription)
        /// Mint a FRC20 token
        access(all)
        fun mint(ins: &Fixes.Inscription)
        /// Transfer a FRC20 token
        access(all)
        fun transfer(ins: &Fixes.Inscription)
        /// Burn a FRC20 token
        access(all)
        fun burn(ins: &Fixes.Inscription): @FlowToken.Vault
        /** ---- Account Methods for command inscriptions ---- */
        /// Parse the metadata of a FRC20 inscription
        access(account) view
        fun parseMetadata(_ data: &Fixes.InscriptionData): {String: String}
        /// Set a FRC20 token to be burnable
        access(account)
        fun setBurnable(ins: &Fixes.Inscription)
        // Burn unsupplied frc20 tokens
        access(account)
        fun burnUnsupplied(ins: &Fixes.Inscription)
        /// Allocate the tokens to some address
        access(account)
        fun allocate(ins: &Fixes.Inscription): @FlowToken.Vault
    }

    /// The resource that stores the inscriptions mapping
    ///
    pub resource InscriptionIndexer: IndexerPublic {
        /// The mapping of tokens
        access(self)
        let tokens: {String: FRC20Meta}
        /// The mapping of balances
        access(self)
        let balances: {String: {Address: UFix64}}
        /// The extracted balance pool of the indexer
        access(self)
        let pool: @{String: FlowToken.Vault}
        /// The treasury of the indexer
        access(self)
        let treasury: @FlowToken.Vault

        init() {
            self.tokens = {}
            self.balances = {}
            self.pool <- {}
            self.treasury <- FlowToken.createEmptyVault() as! @FlowToken.Vault
        }

        destroy() {
            destroy self.treasury
            destroy self.pool
        }

        /* ---- Public methds ---- */

        /// Get all the tokens
        ///
        access(all) view
        fun getTokens(): [String] {
            return self.tokens.keys
        }

        /// Get the meta-info of a token
        ///
        access(all) view
        fun getTokenMeta(tick: String): FRC20Meta? {
            return self.tokens[tick.toLower()]
        }

        /// Get the balance of a FRC20 token
        ///
        access(all) view
        fun getBalance(tick: String, addr: Address): UFix64 {
            let balancesRef = (&self.balances[tick.toLower()] as &{Address: UFix64}?)!
            return balancesRef[addr] ?? 0.0
        }

        /// Get all balances of some address
        ///
        access(all) view
        fun getBalances(addr: Address): {String: UFix64} {
            let ret: {String: UFix64} = {}
            for tick in self.tokens.keys {
                let balancesRef = (&self.balances[tick] as &{Address: UFix64}?)!
                let balance = balancesRef[addr] ?? 0.0
                if balance > 0.0 {
                    ret[tick] = balance
                }
            }
            return ret
        }

        /// Get the holders of a FRC20 token
        access(all) view
        fun getHolders(tick: String): [Address] {
            let balancesRef = (&self.balances[tick.toLower()] as &{Address: UFix64}?)!
            return balancesRef.keys
        }

        /// Get the amount of holders of a FRC20 token
        access(all) view
        fun getHoldersAmount(tick: String): UInt64 {
            return UInt64(self.getHolders(tick: tick.toLower()).length)
        }

        /// Get the pool balance of a FRC20 token
        ///
        access(all) view
        fun getPoolBalance(tick: String): UFix64 {
            let pool = (&self.pool[tick.toLower()] as &FlowToken.Vault?)!
            return pool.balance
        }

        /// Check if an inscription is a valid FRC20 inscription
        ///
        access(all) view
        fun isValidFRC20Inscription(ins: &Fixes.Inscription): Bool {
            let p = ins.getMetaProtocol()
            return ins.getMimeType() == "text/plain" &&
                (p == "FRC20" || p == "frc20" || p == "frc-20" || p == "FRC-20")
        }

        /** ------ Functionality ------  */

        /// Deploy a new FRC20 token
        ///
        access(all)
        fun deploy(ins: &Fixes.Inscription) {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
                self.isValidFRC20Inscription(ins: ins): "The inscription is not a valid FRC20 inscription"
            }
            let meta = self.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
            assert(
                meta["op"] == "deploy" && meta["tick"] != nil && meta["max"] != nil && meta["lim"] != nil,
                message: "The inscription is not a valid FRC20 inscription for deployment"
            )

            let tick = meta["tick"]!.toLower()
            assert(
                tick.length >= 3 && tick.length <= 10,
                message: "The token tick should be between 3 and 10 characters"
            )
            assert(
                self.tokens[tick] == nil && self.balances[tick] == nil && self.pool[tick] == nil,
                message: "The token has already been deployed"
            )
            let max = UFix64.fromString(meta["max"]!) ?? panic("The max supply is not a valid UFix64")
            let limit = UFix64.fromString(meta["lim"]!) ?? panic("The limit is not a valid UFix64")
            let deployer = ins.owner!.address
            let burnable = meta["burnable"] == "true" || meta["burnable"] == "1" // default to false
            self.tokens[tick] = FRC20Meta(
                tick: tick,
                max: max,
                limit: limit,
                deployAt: getCurrentBlock().timestamp,
                deployer: deployer,
                supplied: 0.0,
                burned: 0.0,
                burnable: burnable
            )
            self.balances[tick] = {} // init the balance mapping
            self.pool[tick] <-! FlowToken.createEmptyVault() as! @FlowToken.Vault // init the pool

            // emit event
            emit FRC20Deployed(
                tick: tick,
                max: max,
                limit: limit,
                deployer: deployer
            )

            // extract inscription
            self.extractInscription(tick: tick, ins: ins)
        }

        /// Mint a FRC20 token
        ///
        access(all)
        fun mint(ins: &Fixes.Inscription) {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
                self.isValidFRC20Inscription(ins: ins): "The inscription is not a valid FRC20 inscription"
            }
            let meta = self.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
            assert(
                meta["op"] == "mint" && meta["tick"] != nil && meta["amt"] != nil,
                message: "The inscription is not a valid FRC20 inscription for minting"
            )

            let tick = meta["tick"]!.toLower()
            assert(
                self.tokens[tick] != nil && self.balances[tick] != nil && self.pool[tick] != nil,
                message: "The token has not been deployed"
            )
            let tokenMeta = self.borrowTokenMeta(tick: tick)
            assert(
                tokenMeta.supplied < tokenMeta.max,
                message: "The token has reached the max supply"
            )
            let amt = UFix64.fromString(meta["amt"]!) ?? panic("The amount is not a valid UFix64")
            assert(
                amt > 0.0 && amt <= tokenMeta.limit,
                message: "The amount should be greater than 0.0 and less than the limit"
            )
            let fromAddr = ins.owner!.address

            // get the balance mapping
            let balancesRef = (&self.balances[tick] as &{Address: UFix64}?)!

            // check the limit
            var amtToAdd = amt
            if tokenMeta.supplied + amt > tokenMeta.max {
                amtToAdd = tokenMeta.max.saturatingSubtract(tokenMeta.supplied)
            }
            assert(
                amtToAdd > 0.0,
                message: "The amount should be greater than 0.0"
            )
            // update the balance
            if let oldBalance = balancesRef[fromAddr] {
                balancesRef[fromAddr] = oldBalance.saturatingAdd(amtToAdd)
            } else {
                balancesRef[fromAddr] = amtToAdd
            }
            tokenMeta.updateSupplied(tokenMeta.supplied + amtToAdd)

            // emit event
            emit FRC20Minted(
                tick: tick,
                amount: amtToAdd,
                to: fromAddr
            )

            // extract inscription
            self.extractInscription(tick: tick, ins: ins)
        }

        /// Transfer a FRC20 token
        ///
        access(all)
        fun transfer(ins: &Fixes.Inscription) {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
                self.isValidFRC20Inscription(ins: ins): "The inscription is not a valid FRC20 inscription"
            }
            let meta = self.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
            assert(
                meta["op"] == "transfer" && meta["tick"] != nil && meta["amt"] != nil && meta["to"] != nil,
                message: "The inscription is not a valid FRC20 inscription for transfer"
            )

            let tick = meta["tick"]!.toLower()
            assert(
                self.tokens[tick] != nil && self.balances[tick] != nil && self.pool[tick] != nil,
                message: "The token has not been deployed"
            )
            let tokenMeta = self.borrowTokenMeta(tick: tick)
            let amt = UFix64.fromString(meta["amt"]!) ?? panic("The amount is not a valid UFix64")
            let to = Address.fromString(meta["to"]!) ?? panic("The receiver is not a valid address")
            let fromAddr = ins.owner!.address

            // call the internal transfer method
            self._transferToken(tick: tick, fromAddr: fromAddr, to: to, amt: amt)

            // extract inscription
            self.extractInscription(tick: tick, ins: ins)
        }

        /// Burn a FRC20 token
        ///
        access(all)
        fun burn(ins: &Fixes.Inscription): @FlowToken.Vault {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
                self.isValidFRC20Inscription(ins: ins): "The inscription is not a valid FRC20 inscription"
            }
            let meta = self.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
            assert(
                meta["op"] == "burn" && meta["tick"] != nil && meta["amt"] != nil,
                message: "The inscription is not a valid FRC20 inscription for burning"
            )

            let tick = meta["tick"]!.toLower()
            assert(
                self.tokens[tick] != nil && self.balances[tick] != nil && self.pool[tick] != nil,
                message: "The token has not been deployed"
            )
            let tokenMeta = self.borrowTokenMeta(tick: tick)
            assert(
                tokenMeta.burnable,
                message: "The token is not burnable"
            )
            assert(
                tokenMeta.supplied > tokenMeta.burned,
                message: "The token has been burned out"
            )
            let amt = UFix64.fromString(meta["amt"]!) ?? panic("The amount is not a valid UFix64")
            let fromAddr = ins.owner!.address

            // get the balance mapping
            let balancesRef = (&self.balances[tick] as &{Address: UFix64}?)!

            // check the amount for from address
            let fromBalance = balancesRef[fromAddr] ?? panic("The from address does not have a balance")
            assert(
                fromBalance >= amt && amt > 0.0,
                message: "The from address does not have enough balance"
            )

            let oldBurned = tokenMeta.burned
            balancesRef[fromAddr] = fromBalance.saturatingSubtract(amt)
            tokenMeta.updateBurned(oldBurned + amt)

            // extract inscription
            self.extractInscription(tick: tick, ins: ins)

            // extract flow from pool
            let flowPool = (&self.pool[tick] as &FlowToken.Vault?)!
            let restAmt = tokenMeta.supplied.saturatingSubtract(oldBurned)
            if restAmt > 0.0 {
                let flowTokenToExtract = flowPool.balance * amt / restAmt
                let flowExtracted <- flowPool.withdraw(amount: flowTokenToExtract)
                // emit event
                emit FRC20Burned(
                    tick: tick,
                    amount: amt,
                    from: fromAddr,
                    flowExtracted: flowExtracted.balance
                )
                return <- (flowExtracted as! @FlowToken.Vault)
            } else {
                return <- (FlowToken.createEmptyVault() as! @FlowToken.Vault)
            }
        }

        // ---- Account Methods ----

        /// Parse the metadata of a FRC20 inscription
        ///
        access(account) view
        fun parseMetadata(_ data: &Fixes.InscriptionData): {String: String} {
            let ret: {String: String} = {}
            if data.encoding != nil && data.encoding != "utf8" {
                panic("The inscription is not encoded in utf8")
            }
            // parse the body
            if let body = String.fromUTF8(data.metadata) {
                // split the pairs
                let pairs = StringUtils.split(body, ",")
                for pair in pairs {
                    // split the key and value
                    let kv = StringUtils.split(pair, "=")
                    if kv.length == 2 {
                        ret[kv[0]] = kv[1]
                    }
                }
            } else {
                panic("The inscription is not encoded in utf8")
            }
            return ret
        }

        // ---- Account Methods for command inscriptions ----

        /// Set a FRC20 token to be burnable
        ///
        access(account)
        fun setBurnable(ins: &Fixes.Inscription) {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
                self.isValidFRC20Inscription(ins: ins): "The inscription is not a valid FRC20 inscription"
                // The command inscriptions should be only executed by the indexer
                self.isOwnedByIndexer(ins): "The inscription is not owned by the indexer"
            }
            let meta = self.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
            assert(
                meta["op"] == "burnable" && meta["tick"] != nil && meta["v"] != nil,
                message: "The inscription is not a valid FRC20 inscription for setting burnable"
            )

            let tick = meta["tick"]!.toLower()
            assert(
                self.tokens[tick] != nil && self.balances[tick] != nil && self.pool[tick] != nil,
                message: "The token has not been deployed"
            )
            let tokenMeta = self.borrowTokenMeta(tick: tick)
            let isTrue = meta["v"]! == "true" || meta["v"]! == "1"
            tokenMeta.setBurnable(isTrue)

            // emit event
            emit FRC20BurnableSet(
                tick: tick,
                burnable: isTrue
            )

            // extract inscription
            self.extractInscription(tick: tick, ins: ins)
        }

        /// Burn unsupplied frc20 tokens
        ///
        access(account)
        fun burnUnsupplied(ins: &Fixes.Inscription) {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
                self.isValidFRC20Inscription(ins: ins): "The inscription is not a valid FRC20 inscription"
                // The command inscriptions should be only executed by the indexer
                self.isOwnedByIndexer(ins): "The inscription is not owned by the indexer"
            }
            let meta = self.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
            assert(
                meta["op"] == "burnUnsup" && meta["tick"] != nil && meta["perc"] != nil,
                message: "The inscription is not a valid FRC20 inscription for burning unsupplied tokens"
            )

            let tick = meta["tick"]!.toLower()
            // check the token, the token should be deployed
            assert(
                self.tokens[tick] != nil && self.balances[tick] != nil && self.pool[tick] != nil,
                message: "The token has not been deployed"
            )
            let tokenMeta = self.borrowTokenMeta(tick: tick)
            // check the burnable
            assert(
                tokenMeta.burnable,
                message: "The token is not burnable"
            )
            // check the supplied, should be less than the max
            assert(
                tokenMeta.supplied < tokenMeta.max,
                message: "The token has reached the max supply"
            )

            let perc = UFix64.fromString(meta["perc"]!) ?? panic("The percentage is not a valid UFix64")
            // check the percentage
            assert(
                perc > 0.0 && perc <= 1.0,
                message: "The percentage should be greater than 0.0 and less than or equal to 1.0"
            )

            // update the burned amount
            let totalUnsupplied = tokenMeta.max.saturatingSubtract(tokenMeta.supplied)
            let amtToBurn = totalUnsupplied * perc
            // update the meta-info: supplied and burned
            tokenMeta.updateSupplied(tokenMeta.supplied.saturatingAdd(amtToBurn))
            tokenMeta.updateBurned(tokenMeta.burned.saturatingAdd(amtToBurn))

            // emit event
            emit FRC20UnsuppliedBurned(
                tick: tick,
                amount: amtToBurn
            )

            // extract inscription
            self.extractInscription(tick: tick, ins: ins)
        }

        /// Allocate the tokens to some address
        ///
        access(account)
        fun allocate(ins: &Fixes.Inscription): @FlowToken.Vault {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
                self.isValidFRC20Inscription(ins: ins): "The inscription is not a valid FRC20 inscription"
            }

            let meta = self.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
            assert(
                meta["op"] == "alloc" && meta["tick"] != nil && meta["amt"] != nil && meta["to"] != nil,
                message: "The inscription is not a valid FRC20 inscription for allocating"
            )

            let tick = meta["tick"]!.toLower()
            assert(
                self.tokens[tick] != nil && self.balances[tick] != nil && self.pool[tick] != nil,
                message: "The token has not been deployed"
            )
            let tokenMeta = self.borrowTokenMeta(tick: tick)
            let amt = UFix64.fromString(meta["amt"]!) ?? panic("The amount is not a valid UFix64")
            let to = Address.fromString(meta["to"]!) ?? panic("The receiver is not a valid address")
            let fromAddr = FRC20Indexer.getAddress()

            // call the internal transfer method
            self._transferToken(tick: tick, fromAddr: fromAddr, to: to, amt: amt)

            return <- ins.extract()
        }

        /** ----- Private methods ----- */

        access(self)
        fun extractInscription(tick: String, ins: &Fixes.Inscription) {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
                self.pool[tick] != nil: "The token has not been deployed"
            }

            // extract the tokens
            let token <- ins.extract()
            // 5% of the extracted tokens will be sent to the treasury
            let amtToTreasury = token.balance * 0.05
            // withdraw the tokens to the treasury
            let tokenToTreasuryVault <- token.withdraw(amount: amtToTreasury)

            // deposit the tokens to pool and treasury
            let pool = (&self.pool[tick] as &FlowToken.Vault?)!
            let treasury = &self.treasury as &FlowToken.Vault

            pool.deposit(from: <- token)
            treasury.deposit(from: <- tokenToTreasuryVault)
        }

        /// Internal Transfer a FRC20 token
        ///
        access(self)
        fun _transferToken(
            tick: String,
            fromAddr: Address,
            to: Address,
            amt: UFix64
        ) {
            // get the balance mapping
            let balancesRef = (&self.balances[tick] as &{Address: UFix64}?) ?? panic("The token has not been deployed")

            // check the amount for from address
            let fromBalance = balancesRef[fromAddr] ?? panic("The from address does not have a balance")
            assert(
                fromBalance >= amt && amt > 0.0,
                message: "The from address does not have enough balance"
            )

            balancesRef[fromAddr] = fromBalance.saturatingSubtract(amt)
            // update the balance
            if let oldBalance = balancesRef[to] {
                balancesRef[to] = oldBalance.saturatingAdd(amt)
            } else {
                balancesRef[to] = amt
            }

            // emit event
            emit FRC20Transfer(
                tick: tick,
                from: fromAddr,
                to: to,
                amount: amt
            )
        }

        /// Check if an inscription is owned by the indexer
        ///
        access(self) view
        fun isOwnedByIndexer(_ ins: &Fixes.Inscription): Bool {
            return ins.owner?.address == FRC20Indexer.getAddress()
        }

        /// Borrow the meta-info of a token
        ///
        access(self)
        fun borrowTokenMeta(tick: String): &FRC20Meta {
            let meta = &self.tokens[tick.toLower()] as &FRC20Meta?
            return meta ?? panic("The token meta is not found")
        }
    }

    /* --- Public Methods --- */

    /// Get the address of the indexer
    ///
    access(all)
    fun getAddress(): Address {
        return self.account.address
    }

    /// Get the inscription indexer
    ///
    access(all)
    fun getIndexer(): &InscriptionIndexer{IndexerPublic} {
        let addr = self.account.address
        let cap = getAccount(addr)
            .getCapability<&InscriptionIndexer{IndexerPublic}>(self.IndexerPublicPath)
            .borrow()
        return cap ?? panic("Could not borrow InscriptionIndexer")
    }

    init() {
        let identifier = "FRC20Indexer_".concat(self.account.address.toString())
        self.IndexerStoragePath = StoragePath(identifier: identifier)!
        self.IndexerPublicPath = PublicPath(identifier: identifier)!
        // create the indexer
        self.account.save(<- create InscriptionIndexer(), to: self.IndexerStoragePath)
        self.account.link<&InscriptionIndexer{IndexerPublic}>(self.IndexerPublicPath, target: self.IndexerStoragePath)
    }
}
