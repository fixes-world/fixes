// Third Party Imports
import "FungibleToken"
import "FlowToken"
// Fixes Imports
import "Fixes"
import "FRC20Indexer"
import "FRC20FTShared"

access(all) contract FRC20Staking {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()
    /// Event emitted when the staking pool is created
    access(all) event StakingInitialized(pool: Address, tick: String)
    /// Event emitted when the reward strategy is created
    access(all) event RewardStrategyInitialized(pool: Address, name: String, tick: String, ftVaultType: String?)
    /// Event emitted when the reward strategy is added
    access(all) event RewardStrategyAdded(pool: Address, strategyName: String, stakeTick: String, rewardTick: String)
    /// Event emitted when the reward income is added
    access(all) event RewardIncomeAdded(pool: Address, name: String, tick: String, amount: UFix64, from: Address)
    /// Event emitted when the delegator record is added
    access(all) event DelegatorRecordAdded(pool: Address, tick: String, delegatorID: UInt32, delegatorAddress: Address)

    /// Event emitted when the delegator claim status is updated
    access(all) event DelegatorClaimedReward(pool: Address, strategyName: String, stakeTick: String, rewardTick: String, amount: UFix64, yieldAdded: UFix64)

    /* --- Variable, Enums and Structs --- */
    access(all)
    let StakingPoolStoragePath: StoragePath
    access(all)
    let StakingPoolPublicPath: PublicPath
    access(all)
    let DelegatorStoragePath: StoragePath
    access(all)
    let DelegatorPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    /// Staking Info Struct, represents the staking info of a FRC20 token
    ///
    access(all) struct StakingInfo {
        access(all)
        let tick: String
        access(all)
        let totalStaked: UFix64
        access(all)
        let totalUnstakingLocked: UFix64
        access(all)
        let delegatorsAmount: UInt32
        access(all)
        let rewardStrategies: [String]

        init(
            tick: String,
            totalStaked: UFix64,
            totalUnstakingLocked: UFix64,
            delegatorsAmount: UInt32,
            rewardStrategies: [String]
        ) {
            self.tick = tick
            self.totalStaked = totalStaked
            self.totalUnstakingLocked = totalUnstakingLocked
            self.delegatorsAmount = delegatorsAmount
            self.rewardStrategies = rewardStrategies
        }
    }

    access(all) resource interface StakingPublic {
        /// The ticker name of the FRC20 Staking Pool
        access(all)
        let tick: String
        /// Returns the details of the staking pool
        access(all) view
        fun getDetails(): StakingInfo
        /// Returns the delegator ID of the given address
        access(all) view
        fun getDelegatorID(_ addr: Address): UInt32?
        /// Returns the reward strategy names
        access(all) view
        fun getRewardNames(): [String]
        /// Returns the reward details of the given name
        access(all) view
        fun getRewardDetails(_ name: String): RewardDetails?
    }

    access(all) resource Staking: StakingPublic {
        /// The ticker name of the FRC20 Staking Pool
        access(all)
        let tick:String
        /// The total FRC20 tokens staked in the pool
        access(contract)
        let totalStaked: @FRC20FTShared.Change
        /// The total FRC20 tokens unstaked in the pool and able to withdraw after the lock period
        access(contract)
        let totalUnstakingLocked: @FRC20FTShared.Change
        /** ----- Delegators ---- */
        /// The delegator ID counter
        access(all)
        var delegatorIDCounter: UInt32
        /// The delegators of this staking pool
        access(self)
        let delegators: @{UInt32: DelegatorRecord}
        /// The delegator address to ID mapping
        access(self)
        let delegatorAddrToID: {Address: UInt32}
        /** ----- Rewards ----- */
        /// The rewards of this staking pool
        access(contract)
        let rewards: @{String: RewardStrategy}

        init(
            _ tick: String,
            pool: &Pool
        ) {
            pre {
                pool.owner?.address != nil: "Pool owner must be set"
            }
            let owner = pool.owner?.address!

            self.tick = tick
            self.totalStaked <- FRC20FTShared.createChange(tick: tick, from: owner, balance: 0.0, ftVault: nil)
            self.totalUnstakingLocked <- FRC20FTShared.createChange(tick: tick, from: owner, balance: 0.0, ftVault: nil)
            self.delegators <- {}
            self.delegatorIDCounter = 0
            self.delegatorAddrToID = {}
            self.rewards <- {}

            // emit event
            emit StakingInitialized(pool: owner, tick: tick)
        }

        /// @deprecated after Cadence 1.0
        destroy() {
            destroy self.totalStaked
            destroy self.totalUnstakingLocked
            destroy self.delegators
            destroy self.rewards
        }

        /** ---- Public Methods ---- */

        access(all) view
        fun getDetails(): StakingInfo {
            return StakingInfo(
                tick: self.tick,
                totalStaked: self.totalStaked.getBalance(),
                totalUnstakingLocked: self.totalUnstakingLocked.getBalance(),
                delegatorsAmount: UInt32(self.delegators.keys.length),
                rewardStrategies: self.getRewardNames()
            )
        }

        access(all) view
        fun getDelegatorID(_ addr: Address): UInt32? {
            return self.delegatorAddrToID[addr]
        }

        access(all) view
        fun getRewardNames(): [String] {
            return self.rewards.keys
        }

        access(all) view
        fun getRewardDetails(_ name: String): RewardDetails? {
            if let reward = self.borrowRewardStrategy(name) {
                return RewardDetails(
                    name: reward.name,
                    stakeTick: reward.stakeTick,
                    rewardTick: reward.rewardTick,
                    totalReward: reward.totalReward.getBalance()
                )
            }
            return nil
        }

        /** ---- Contract Level Methods ----- */

        /// Borrow Delegator Record
        ///
        access(contract)
        fun borrowDelegatorRecord(_ delegatorID: UInt32): &DelegatorRecord? {
            return &self.delegators[delegatorID] as &DelegatorRecord?
        }

        /// Borrow Delegator Record by Address
        ///
        access(contract)
        fun borrowDelegatorRecordByAddress(_ addr: Address): &DelegatorRecord? {
            if let id = self.getDelegatorID(addr) {
                return self.borrowDelegatorRecord(id)
            }
            return nil
        }

        /// Borrow Reward Strategy
        ///
        access(contract)
        fun borrowRewardStrategy(_ name: String): &RewardStrategy? {
            return &self.rewards[name] as &RewardStrategy?
        }

        /// Add the Delegator Record
        ///
        access(contract)
        fun addDelegator(_ delegator: @DelegatorRecord) {
            pre {
                self.delegators[delegator.id] == nil: "Delegator id already exists"
            }
            let delegatorID = delegator.id
            self.delegatorAddrToID[delegator.delegator] = delegatorID
            self.delegators[delegatorID] <-! delegator

            // increase delegator ID counter
            self.delegatorIDCounter = self.delegatorIDCounter + 1

            let ref = self.borrowDelegatorRecord(delegatorID)
                ?? panic("Delegator record must exist")

            // emit event
            emit DelegatorRecordAdded(
                pool: self.owner?.address ?? panic("Pool owner must exist"),
                tick: self.tick,
                delegatorID: delegatorID,
                delegatorAddress: ref.delegator
            )
        }

        /// register reward strategy
        access(contract)
        fun registerRewardStrategy(_ strategy: @RewardStrategy) {
            pre {
                self.rewards[strategy.name] == nil: "Reward strategy name already exists"
            }
            let name = strategy.name
            let rewardTick = strategy.rewardTick
            self.rewards[name] <-! strategy

            // emit event
            emit RewardStrategyAdded(
                pool: self.owner?.address ?? panic("Reward owner must exist"),
                strategyName: name,
                stakeTick: self.tick,
                rewardTick: rewardTick
            )
        }
    }

    /// Delegator Record Resource, represents a delegator record for a FRC20 token and store in pool's account
    ///
    access(all) resource DelegatorRecord {
        // The delegator ID
        access(all)
        let id: UInt32
        // The delegator address
        access(all)
        let delegator: Address
        // Record unstaking status

        init(
            _ id: UInt32,
            _ address: Address
        ) {
            pre {
                FRC20Staking.borrowDelegator(address) != nil: "Delegator must exist"
            }
            self.id = id
            self.delegator = address
        }

        /// Borrow Delegator reference
        ///
        access(contract)
        fun borrowDelegatorRef(): &Delegator{DelegatorPublic} {
            return FRC20Staking.borrowDelegator(self.delegator) ?? panic("Delegator must exist")
        }
    }

    /// Reward Details Struct, represents a reward details for a FRC20 token
    ///
    access(all) struct RewardDetails {
        access(all)
        let name: String
        access(all)
        let stakeTick: String
        access(all)
        let rewardTick: String
        access(all)
        let totalReward: UFix64

        init(
            name: String,
            stakeTick: String,
            rewardTick: String,
            totalReward: UFix64
        ) {
            self.name = name
            self.stakeTick = stakeTick
            self.rewardTick = rewardTick
            self.totalReward = totalReward
        }
    }

    /// Reward strategy Public Interface
    ///
    access(all) resource interface RewardStrategyPublic {
        /// The name of the reward strategy
        access(all)
        let name: String
        /// The ticker name of staking pool
        access(all)
        let stakeTick: String
        /// The ticker name of reward
        access(all)
        let rewardTick: String
        /// The global yield rate of the reward strategy
        access(contract)
        var globalYieldRate: UFix64

        /// Get the unique name of the reward strategy
        access(all) view
        fun getUniqueName(): String
    }

    /// Reward Strategy Resource, represents a reward strategy for a FRC20 token and store in pool's account
    ///
    access(all) resource RewardStrategy: RewardStrategyPublic {
        /// The name of the reward strategy
        access(all)
        let name: String
        /// The ticker name of staking pool
        access(all)
        let stakeTick: String
        /// The ticker name of reward
        access(all)
        let rewardTick: String
        /// The reward change, can be any FRC20 token or Flow FT
        access(contract)
        let totalReward: @FRC20FTShared.Change
        /// The global yield rate of the reward strategy
        access(contract)
        var globalYieldRate: UFix64

        init(
            name: String,
            rewardTick: String,
            _ pool: &Pool,
        ) {
            pre {
                pool.owner?.address != nil: "Pool owner must be set"
            }
            let owner = pool.owner?.address!

            self.name = name
            self.stakeTick = pool.tick
            self.rewardTick = rewardTick
            self.globalYieldRate = 0.0

            // current only support FlowToken
            let isFtVault = rewardTick == ""
            /// create empty change
            if isFtVault {
                // TODO: support other Flow FT
                self.totalReward <- FRC20FTShared.createChange(tick: rewardTick, from: owner, balance: nil, ftVault: <- FlowToken.createEmptyVault())
            } else {
                self.totalReward <- FRC20FTShared.createChange(tick: rewardTick, from: owner, balance: 0.0, ftVault: nil)
            }

            // emit event
            emit RewardStrategyInitialized(
                pool: owner,
                name: name,
                tick: rewardTick,
                ftVaultType: isFtVault ? self.totalReward.getVaultType()?.identifier! : nil
            )
        }

        /// @deprecated after Cadence 1.0
        destroy() {
            destroy self.totalReward
        }

        /// Get the unique name of the reward strategy
        ///
        access(all) view
        fun getUniqueName(): String {
            let addr = self.owner?.address ?? panic("Owner must be set")
            return addr.toString().concat("_").concat(self.rewardTick).concat("_").concat(self.name)
        }

        access(contract)
        fun addIncome(income: @FRC20FTShared.Change, pool: &Pool) {
            pre {
                self.owner?.address == pool.owner?.address: "Pool owner must match with reward strategy owner"
                pool.tick == self.stakeTick: "Pool tick must match with reward strategy tick"
                income.tick == self.rewardTick: "Income tick must match with reward strategy tick"
            }

            let incomeFrom = income.from
            let incomeValue = income.getBalance()
            if incomeValue > 0.0 {
                let stakingRef = pool.borrowStakingRef()

                // add to total reward and update global yield rate
                let totalStakedToken = stakingRef.totalStaked.getBalance()
                // update global yield rate
                self.globalYieldRate = self.globalYieldRate + incomeValue / totalStakedToken
                // add to total reward
                FRC20FTShared.depositToChange(
                    receiver: self.borrowRewardRef(),
                    change: <- income
                )

                // emit event
                emit RewardIncomeAdded(
                    pool: pool.owner?.address!,
                    name: self.name,
                    tick: self.rewardTick,
                    amount: incomeValue,
                    from: incomeFrom
                )
            } else {
                destroy income
            }
        }

        access(contract)
        fun claim(by: &DelegatorRecord, pool: &Pool): @FRC20FTShared.Change {
            pre {
                self.owner?.address == pool.owner?.address: "Pool owner must match with reward strategy owner"
                pool.tick == self.stakeTick: "Pool tick must match with reward strategy tick"
            }
            let stakingRef = pool.borrowStakingRef()
            let rewardUniqueName = self.getUniqueName()

            // global info
            let totalStakedToken = stakingRef.totalStaked.getBalance()
            let totalRewardBalance = self.totalReward.getBalance()

            // delegator info
            let delegatorID = by.id
            let delegatorRecordRef = stakingRef.borrowDelegatorRecord(delegatorID)
                ?? panic("Delegator record must exist")
            let delegatorRef = delegatorRecordRef.borrowDelegatorRef()
            let delegatorClaimingRef = delegatorRef.borrowClaimingRecord(rewardUniqueName)

            // calculate reward
            let delegatorLastGlobalYieldRate = delegatorClaimingRef?.lastGlobalYieldRate ?? 0.0
            let delegatorStakedToken = delegatorRef.getStakedBalance(tick: self.stakeTick)

            assert(
                self.globalYieldRate > delegatorLastGlobalYieldRate,
                message: "You can only claim reward after global yield rate is updated"
            )
            // This is reward to distribute
            let yieldReward = (self.globalYieldRate - delegatorLastGlobalYieldRate) * delegatorStakedToken
            assert(
                yieldReward <= totalRewardBalance,
                message: "Reward must be less than total reward"
            )
            // withdraw from totalReward
            var ret: @FRC20FTShared.Change? <- nil
            if self.totalReward.isBackedByVault() {
                let vault <- self.totalReward.withdrawAsVault(amount: yieldReward)
                ret <-! FRC20FTShared.createChange(
                    tick: self.totalReward.tick,
                    from: self.totalReward.from,
                    balance: nil,
                    ftVault: <- vault
                )
            } else {
                ret <-! self.totalReward.withdrawAsChange(amount: yieldReward)
            }

            // update delegator claiming record
            delegatorRef.onClaimingReward(
                reward: self.borrowSelf(),
                amount: yieldReward,
                currentGlobalYieldRate: self.globalYieldRate
            )

            // emit event
            emit DelegatorClaimedReward(
                pool: self.owner?.address ?? panic("Reward owner must exist"),
                strategyName: self.name,
                stakeTick: self.stakeTick,
                rewardTick: self.rewardTick,
                amount: yieldReward,
                yieldAdded: self.globalYieldRate
            )

            // return the change
            return <- (ret ?? panic("Reward must exist"))
        }

        /** ---- Internal Methods ---- */

        access(self)
        fun borrowRewardRef(): &FRC20FTShared.Change {
            return &self.totalReward as &FRC20FTShared.Change
        }

        access(self)
        fun borrowSelf(): &RewardStrategy {
            return &self as &RewardStrategy
        }
    }

    /// Staking Pool Public Interface
    ///
    access(all) resource interface PoolPublic {
        // ---- Public read methods ----
        access(all) view
        fun getStakingTickerName(): String

        // ---- Operations ----
    }

    /// Staking Pool Resource, represents a staking pool and store in platform staking pool child account
    ///
    access(all) resource Pool: PoolPublic {
        /// The ticker name of the FRC20 Staking Pool
        access(all)
        let tick:String
        /// The total FRC20 tokens staked in the pool
        access(contract)
        var record: @Staking?

        init(
            tick: String
        ) {
            self.tick = tick

            self.record <- nil
        }

        /// @deprecated after Cadence 1.0
        destroy() {
            destroy self.record
        }

        /// Initialize the staking record
        ///
        access(all)
        fun initialize() {
            pre {
                self.record == nil: "Staking record must not exist"
            }
            self.record <-! create Staking(self.tick, pool: self.borrowSelf())
        }

        /** ---- Public Methods ---- */

        /// The ticker name of the FRC20 market
        ///
        access(all) view
        fun getStakingTickerName(): String {
            return self.tick
        }

        /** ---- Internal Methods ---- */

        /// Borrow Staking Record
        ///
        access(contract)
        fun borrowStakingRef(): &Staking {
            return &self.record as &Staking? ?? panic("Staking record must exist")
        }

        /// Borrow Pool Reference
        ///
        access(self)
        fun borrowSelf(): &Pool {
            return &self as &Pool
        }
    }

    /// Reward Claiming Record Struct, stored in delegator's resource
    ///
    access(all) struct RewardClaimRecord {
        // The pool address
        access(all)
        let poolAddress: Address
        // The reward strategy name
        access(all)
        let rewardStrategy: String
        // The last claimed time
        access(all)
        var lastClaimedTime: UInt64
        // The last global yield rate
        access(all)
        var lastGlobalYieldRate: UFix64
        // The total claimed amount
        access(all)
        var totalClaimedAmount: UFix64

        init (
            address: Address,
            name: String,
        ) {
            self.poolAddress = address
            self.rewardStrategy = name
            self.lastClaimedTime = 0
            self.lastGlobalYieldRate = 0.0
            self.totalClaimedAmount = 0.0
        }

        /// Update the claiming record
        ///
        access(contract)
        fun updateClaiming(amount: UFix64, currentGlobalYieldRate: UFix64) {
            self.lastClaimedTime = UInt64(getCurrentBlock().timestamp)
            self.lastGlobalYieldRate = currentGlobalYieldRate
            self.totalClaimedAmount = self.totalClaimedAmount + amount
        }
    }

    /// Delegator Public Interface
    ///
    access(all) resource interface DelegatorPublic {
        /** ---- Public methods ---- */
        /// Get the staked frc20 token balance of the delegator
        access(all) view
        fun getStakedBalance(tick: String): UFix64

        /** ---- Contract level methods ---- */
        /// Borrow the claiming record
        access(contract)
        fun borrowClaimingRecord(_ uniqueName: String): &RewardClaimRecord?

        /// Update the claiming record
        access(contract)
        fun onClaimingReward(
            reward: &RewardStrategy{RewardStrategyPublic},
            amount: UFix64,
            currentGlobalYieldRate: UFix64
        )
    }

    /// Delegator Resource, represents a delegator and store in user's account
    ///
    access(all) resource Delegator: DelegatorPublic {
        // Tick(original name) => Staked Tick Change
        access(contract)
        let stakedTicks: @{String: FRC20FTShared.Change}
        // Unique Name => Reward Claim Record
        access(self)
        let claimingRecords: {String: RewardClaimRecord}

        init() {
            self.stakedTicks <- {}
            self.claimingRecords = {}
        }

        /// @deprecated after Cadence 1.0
        destroy() {
            destroy self.stakedTicks
        }

        /** ----- Public Methods ----- */

        /// Get the staked frc20 token balance of the delegator
        ///
        access(all) view
        fun getStakedBalance(tick: String): UFix64 {
            if let change = self.borrowStakedChange(tick) {
                assert(change.getOriginalTick() == tick, message: "Staked change tick must match")
                return change.getBalance()
            }
            return 0.0
        }

        /** ----- Contract Methods ----- */

        /// Update the claiming record
        access(contract)
        fun onClaimingReward(
            reward: &RewardStrategy{RewardStrategyPublic},
            amount: UFix64,
            currentGlobalYieldRate: UFix64
        ) {
            let uid = reward.getUniqueName()
            let owner = reward.owner?.address ?? panic("Reward owner must exist")
            if self.claimingRecords[uid] == nil {
                self.claimingRecords[uid] = RewardClaimRecord(
                    address: owner,
                    name: reward.name, // use basic name
                )
            }
            // update claiming record
            let recordRef = self.borrowClaimingRecord(uid)
                ?? panic("Claiming record must exist")
            recordRef.updateClaiming(amount: amount, currentGlobalYieldRate: currentGlobalYieldRate)
        }

        access(contract)
        fun borrowClaimingRecord(_ uniqueName: String): &RewardClaimRecord? {
            return &self.claimingRecords[uniqueName] as &RewardClaimRecord?
        }

        /** ----- Internal Methods ----- */

        /// Borrow Staked Change
        ///
        access(self)
        fun borrowStakedChange(_ tick: String): &FRC20FTShared.Change? {
            return &self.stakedTicks[tick] as &FRC20FTShared.Change?
        }
    }

    /** ---- public methods ---- */

    /// Borrow Pool by address
    ///
    access(all)
    fun borrowPool(_ addr: Address): &Pool{PoolPublic}? {
        return getAccount(addr)
            .getCapability<&Pool{PoolPublic}>(self.StakingPoolPublicPath)
            .borrow()
    }

    /// Borrow Delegate by address
    ///
    access(all)
    fun borrowDelegator(_ addr: Address): &Delegator{DelegatorPublic}? {
        return getAccount(addr)
            .getCapability<&Delegator{DelegatorPublic}>(self.DelegatorPublicPath)
            .borrow()
    }

    init() {
        let identifier = "FRC20Staking_".concat(self.account.address.toString())
        self.StakingPoolStoragePath = StoragePath(identifier: identifier.concat("_pool"))!
        self.StakingPoolPublicPath = PublicPath(identifier: identifier.concat("_pool"))!
        self.DelegatorStoragePath = StoragePath(identifier: identifier.concat("_delegator"))!
        self.DelegatorPublicPath = PublicPath(identifier: identifier.concat("_delegator"))!

        emit ContractInitialized()
    }
}
