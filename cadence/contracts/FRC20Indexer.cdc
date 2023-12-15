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
    pub event FRC20Transfer(from: Address, to: Address, amount: UFix64)
    /// Event emitted when a FRC20 token is burned
    pub event FRC20Burned(tick: String, amount: UFix64, from: Address, flowExtracted: UFix64)

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
        access(all) var supplied: UFix64
        access(all) var burned: UFix64

        init(
            tick: String,
            max: UFix64,
            limit: UFix64,
            supplied: UFix64,
            burned: UFix64
        ) {
            self.tick = tick
            self.max = max
            self.limit = limit
            self.supplied = supplied
            self.burned = burned
        }

        access(all)
        fun updateSupplied(_ amt: UFix64) {
            self.supplied = amt
        }

        access(all)
        fun updateBurned(_ amt: UFix64) {
            self.burned = amt
        }
    }

    pub resource interface IndexerPublic {
        // read-only
        access(all) view
        fun getTokenMeta(tick: String): FRC20Meta?
        access(all) view
        fun isValidFRC20Inscription(ins: &Fixes.Inscription): Bool
        // write
        access(all)
        fun deploy(ins: &Fixes.Inscription)
        access(all)
        fun mint(ins: &Fixes.Inscription)
        access(all)
        fun transfer(ins: &Fixes.Inscription)
        access(all)
        fun burn(ins: &Fixes.Inscription): @FlowToken.Vault
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

        /// Get the meta-info of a token
        ///
        access(all) view
        fun getTokenMeta(tick: String): FRC20Meta? {
            return self.tokens[tick]
        }

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

            let tick = meta["tick"]!
            assert(
                self.tokens[tick] == nil && self.balances[tick] == nil && self.pool[tick] == nil,
                message: "The token has already been deployed"
            )
            let max = UFix64.fromString(meta["max"]!) ?? panic("The max supply is not a valid UFix64")
            let limit = UFix64.fromString(meta["lim"]!) ?? panic("The limit is not a valid UFix64")
            self.tokens[tick] = FRC20Meta(
                tick: tick,
                max: max,
                limit: limit,
                supplied: 0.0,
                burned: 0.0
            )
            self.balances[tick] = {} // init the balance mapping
            self.pool[tick] <-! FlowToken.createEmptyVault() as! @FlowToken.Vault // init the pool

            // extract inscription
            self.extractInscription(tick: tick, ins: ins)

            // emit event
            emit FRC20Deployed(
                tick: tick,
                max: max,
                limit: limit,
                deployer: ins.owner!.address
            )
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

            let tick = meta["tick"]!
            assert(
                self.tokens[tick] != nil && self.balances[tick] != nil && self.pool[tick] != nil,
                message: "The token has not been deployed"
            )
            let tokenMeta = self.borrowTokenMeta(tick: tick)
            let amt = UFix64.fromString(meta["amt"]!) ?? panic("The amount is not a valid UFix64")
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

            // extract inscription
            self.extractInscription(tick: tick, ins: ins)

            // emit event
            emit FRC20Minted(
                tick: tick,
                amount: amtToAdd,
                to: fromAddr
            )
        }

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

            let tick = meta["tick"]!
            assert(
                self.tokens[tick] != nil && self.balances[tick] != nil && self.pool[tick] != nil,
                message: "The token has not been deployed"
            )
            let tokenMeta = self.borrowTokenMeta(tick: tick)
            let amt = UFix64.fromString(meta["amt"]!) ?? panic("The amount is not a valid UFix64")
            let to = Address.fromString(meta["to"]!) ?? panic("The receiver is not a valid address")
            let fromAddr = ins.owner!.address

            // get the balance mapping
            let balancesRef = (&self.balances[tick] as &{Address: UFix64}?)!

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

            // extract inscription
            self.extractInscription(tick: tick, ins: ins)

            // emit event
            emit FRC20Transfer(
                from: fromAddr,
                to: to,
                amount: amt
            )
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

            let tick = meta["tick"]!
            assert(
                self.tokens[tick] != nil && self.balances[tick] != nil && self.pool[tick] != nil,
                message: "The token has not been deployed"
            )
            let tokenMeta = self.borrowTokenMeta(tick: tick)
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
                let flowExtracted <- flowPool.withdraw(amount: flowTokenToExtract) as! @FlowToken.Vault
                // emit event
                emit FRC20Burned(
                    tick: tick,
                    amount: amt,
                    from: fromAddr,
                    flowExtracted: flowExtracted.balance
                )
                return <- flowExtracted
            } else {
                return <- (FlowToken.createEmptyVault() as! @FlowToken.Vault)
            }
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

        /// Parse the metadata of a FRC20 inscription
        ///
        access(self)
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

        access(self)
        fun borrowTokenMeta(tick: String): &FRC20Meta {
            let meta = &self.tokens[tick] as &FRC20Meta?
            return meta ?? panic("The token meta is not found")
        }
    }

    /// Get the inscription indexer
    ///
    access(all)
    fun getIndexer(): &InscriptionIndexer{IndexerPublic} {
        let addr = self.account.address
        let cap = getAccount(addr)
            .capabilities
            .borrow<&InscriptionIndexer{IndexerPublic}>(self.IndexerPublicPath)
        return cap ?? panic("Could not borrow InscriptionIndexer")
    }

    init() {
        let identifier = "FRC20Indexer_".concat(self.account.address.toString())
        self.IndexerStoragePath = StoragePath(identifier: identifier)!
        self.IndexerPublicPath = PublicPath(identifier: identifier)!
        // create the indexer
        self.account.save(<- create InscriptionIndexer(), to: self.IndexerStoragePath)
        let cap = self.account
            .capabilities.storage
            .issue<&InscriptionIndexer{IndexerPublic}>(self.IndexerStoragePath)
        self.account.capabilities.publish(cap, at: self.IndexerPublicPath)
    }
}
