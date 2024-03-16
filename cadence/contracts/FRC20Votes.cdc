/**
> Author: FIXeS World <https://fixes.world/>

# FRC20Votes

TODO: Add description

*/
import "NonFungibleToken"
import "Fixes"
import "FixesHeartbeat"
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20SemiNFT"
import "FRC20Staking"

access(all) contract FRC20Votes {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /// Event emitted when a proposal is created
    access(all) event ProposalCreated(
        proposer: Address,
        tick: String,
        proposalId: UInt64,
        title: String,
        message: String,
        discussionLink: String,
        executableThreshold: UFix64,
        beginningTime: UFix64,
        endingTime: UFix64,
        slots: UInt8,
        slotsInscriptions: {UInt8: [UInt64]}
    )
    /// Event emitted when a proposal status is changed
    access(all) event ProposalStatusChanged(
        proposalId: UInt64,
        tick: String,
        prevStatus: UInt8?,
        newStatus: UInt8,
        timestamp: UFix64
    )
    /// Event emitted when a proposal is updated
    access(all) event ProposalInfoUpdated(
        proposalId: UInt64,
        tick: String,
        title: String?,
        message: String?,
        discussionLink: String?
    )
    /// Event emitted when a proposal is cancelled
    access(all) event ProposalCancelled(
        proposalId: UInt64,
        tick: String
    )

    /// Event emitted when a proposal is voted
    access(all) event ProposalVoted(
        tick: String,
        proposalId: UInt64,
        voter: Address,
        choice: UInt8,
        points: UFix64,
    )

    /// Event emitted when a proposal is failed
    access(all) event ProposalFailed(
        tick: String,
        proposalId: UInt64,
        votedPoints: UFix64,
        failedAt: UFix64
    )

    /// Event emitted when a proposal is executed
    access(all) event ProposalExecuted(
        tick: String,
        proposalId: UInt64,
        choice: UInt8,
        executedAt: UFix64
    )

    /* --- Variable, Enums and Structs --- */

    access(all)
    let VoterStoragePath: StoragePath
    access(all)
    let VoterPublicPath: PublicPath
    access(all)
    let FRC20VotesManagerStoragePath: StoragePath
    access(all)
    let FRC20VotesManagerPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    /// The Proposal status.
    ///
    access(all) enum ProposalStatus: UInt8 {
        access(all) case Created;
        access(all) case Activated;
        access(all) case Cancelled;
        access(all) case Failed;
        access(all) case Successed;
        access(all) case Executed;
    }

    /// The Proposal command type.
    ///
    access(all) enum CommandType: UInt8 {
        access(all) case SetBurnable;
        access(all) case BurnUnsupplied;
        access(all) case MoveToLotteryJackpot;
    }

    access(all) resource interface VoterPublic {
        access(all)
        fun hasVoted(proposalId: UInt64): Bool
        access(all)
        fun getVotedProposals(tick: String): [UInt64]
    }

    /// The resource of the FixesVotes voter identifier.
    ///
    access(all) resource VoterIdentity: VoterPublic, FRC20SemiNFT.FRC20SemiNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        access(self)
        let voted: {UInt64: Bool}
        access(self)
        let votedTicksMapping: {String: [UInt64]}
        access(self)
        let lockedSemiNFTs: @{UInt64: FRC20SemiNFT.NFT}

        init() {
            self.lockedSemiNFTs <- {}
            self.voted = {}
            self.votedTicksMapping = {}
        }

        destroy() {
            destroy self.lockedSemiNFTs
        }

        /** ----- Read ----- */

        access(all)
        fun hasVoted(proposalId: UInt64): Bool {
            return self.voted[proposalId] != nil
        }

        access(all)
        fun getVotedProposals(tick: String): [UInt64] {
            if let voted = self.votedTicksMapping[tick] {
                return voted
            } else {
                return []
            }
        }

        /** ----- Write ----- */

        access(contract)
        fun onVote(tick: String, proposalId: UInt64) {
            pre {
                self.voted[proposalId] == false: "Proposal is already voted"
            }
            post {
                self.voted[proposalId] == true: "Proposal is not voted"
                self.votedTicksMapping[tick]?.length! == before(self.votedTicksMapping[tick]?.length!) + 1: "Proposal is not added to the tick"
            }
            self.voted[proposalId] = true
            if self.votedTicksMapping[tick] == nil {
                self.votedTicksMapping[tick] = [proposalId]
            } else {
                self.votedTicksMapping[tick]?.append(proposalId)
            }
        }
    }

    /// The struct of the FixesVotes proposal details.
    ///
    access(all) struct ProposalDetails {
        access(all)
        let proposer: Address
        access(all)
        let tick: String
        access(all)
        let slots: UInt8
        access(all)
        let slotsInscriptions: {UInt8: [UInt64]}
        access(all)
        let beginningTime: UFix64
        access(all)
        let endingTime: UFix64
        access(all)
        let executableThreshold: UFix64
        // ------ vars ------
        access(all)
        var title: String
        access(all)
        var message: String
        access(all)
        var discussionLink: String
        access(all)
        var isCancelled: Bool
        // ----- Voting status -----
        /// Address -> Points
        access(all)
        var votedAccounts: {Address: UFix64}
        /// NFTId -> Bool
        access(all)
        var votedNFTs: {UInt64: Bool}
        /// Vote choice -> Points
        access(all)
        var votes: {UInt8: UFix64}

        init(
            proposer: Address,
            tick: String,
            title: String,
            message: String,
            discussionLink: String,
            executableThreshold: UFix64,
            beginningTime: UFix64,
            endingTime: UFix64,
            slots: UInt8,
            slotsInscriptions: {UInt8: [UInt64]}
        ) {
            pre {
                slots > 0: "Slots must be greater than 0"
                executableThreshold >= 0.1 && executableThreshold <= 0.8: "Executable threshold must be between 0.1 and 0.8"
                beginningTime < endingTime: "Beginning time must be less than ending time"
            }
            self.proposer = proposer
            self.tick = tick
            self.title = title
            self.message = message
            self.discussionLink = discussionLink
            self.slots = slots
            self.slotsInscriptions = slotsInscriptions
            self.beginningTime = beginningTime
            self.endingTime = endingTime
            self.executableThreshold = executableThreshold
            self.isCancelled = false
            self.votedAccounts = {}
            self.votedNFTs = {}
            // init votes
            self.votes = {}
            var i = 0 as UInt8
            while i < slots {
                self.votes[i] = 0.0
                i = i + 1
            }
        }

        /** ----- Read ----- */

        /// The Proposal is ended if the endAt is not nil.
        ///
        access(all) view
        fun isEnded(): Bool {
            return self.endingTime <= getCurrentBlock().timestamp
        }

        /// Get the voters amount.
        ///
        access(all) view
        fun getVotersAmount(): Int {
            return self.votedAccounts.length
        }

        /// Get the total voted points.
        ///
        access(all) view
        fun getTotalVotedPoints(): UFix64 {
            var total = 0.0
            for k in self.votes.keys {
                total = total + self.votes[k]!
            }
            return total
        }

        /// Get the winning choice.
        ///
        access(all) view
        fun getWinningChoice(): UInt8? {
            if !self.isEnded() {
                return nil
            }
            // get the winning choice
            var winningChoice = 0 as UInt8
            var winningVotes = 0.0
            for k in self.votes.keys {
                if let points = self.votes[k] {
                    if points > winningVotes {
                        winningChoice = k
                        winningVotes = points
                    }
                }
            }
            return winningChoice
        }

        /// WHether the proposal is validate for the threshold.
        ///
        access(all) view
        fun isValidateForThreshold(): Bool {
            if !self.isEnded() {
                return false
            }
            let totalStaked = FRC20Votes.getTotalStakedAmount()
            let votedAmount = self.getTotalVotedPoints()
            return totalStaked * self.executableThreshold <= votedAmount
        }

        /// Get current status.
        ///
        access(all) view
        fun getCurrentStatus(): ProposalStatus {
            let now = getCurrentBlock().timestamp
            if self.isCancelled {
                return ProposalStatus.Cancelled
            } else if now < self.beginningTime {
                return ProposalStatus.Created
            } else if now < self.endingTime {
                return ProposalStatus.Activated
            } else {
                // ended
                if !self.isValidateForThreshold() {
                    return ProposalStatus.Failed
                } else if !self.isWinningInscriptionAllExecuted() {
                    return ProposalStatus.Successed
                } else {
                    return ProposalStatus.Executed
                }
            }
        }

        access(all) view
        fun isWinningInscriptionAllExecuted(): Bool {
            if !self.isEnded() {
                return false
            }
            if let winningChoice = self.getWinningChoice() {
                let winningInsIds = self.slotsInscriptions[winningChoice]!
                let inscriptionsStore = FRC20Votes.borrowSystemInscriptionsStore()
                var allExecuted = true
                for id in winningInsIds {
                    let insRef = inscriptionsStore.borrowInscription(id)
                    allExecuted = allExecuted && (insRef?.isExtracted() ?? false)
                    if !allExecuted {
                        break
                    }
                }
                return allExecuted
            }
            return false
        }

        /// Check whether the NFT is voted.
        ///
        access(all) view
        fun isVoted(_ semiNFT: &FRC20SemiNFT.NFT{FRC20SemiNFT.IFRC20SemiNFT}): Bool {
            return self.votedNFTs[semiNFT.id] != nil
        }

        /** ----- Write ----- */

        access(contract)
        fun updateProposal(title: String?, message: String?, discussionLink: String?) {
            pre {
                self.getCurrentStatus().rawValue <= ProposalStatus.Activated.rawValue: "Proposal is not in the right status"
            }
            if title != nil {
                self.title = title!
            }
            if message != nil {
                self.message = message!
            }
            if discussionLink != nil {
                self.discussionLink = discussionLink!
            }
        }

        access(contract)
        fun cancelProposal() {
            pre {
                self.getCurrentStatus().rawValue <= ProposalStatus.Activated.rawValue: "Proposal is not in the right status"
            }
            self.isCancelled = true
        }

        access(contract)
        fun vote(choice: UInt8, semiNFT: &FRC20SemiNFT.NFT{FRC20SemiNFT.IFRC20SemiNFT}) {
            pre {
                self.getCurrentStatus() == ProposalStatus.Activated: "Proposal is not in voting status"
                choice < self.slots: "Choice is out of range"
                semiNFT.isStakedTick(): "The ticker is not staked"
                semiNFT.getOriginalTick() == FRC20Votes.getStakingTickerName(): "The ticker is not the staking ticker"
                semiNFT.getBalance() > 0.0: "The NFT balance is zero"
                self.votedNFTs[semiNFT.id] == nil: "NFT is already voted"
            }
            post {
                self.votes[choice]! == before(self.votes[choice]!) + semiNFT.getBalance(): "Votes are not added"
                self.votedNFTs[semiNFT.id] == true: "NFT is not added to the votedNFTs"
            }
            let points = semiNFT.getBalance()
            self.votes[choice] = (self.votes[choice] ?? 0.0) + points
            // add the voter
            let voterAddr = semiNFT.owner?.address ?? panic("Voter's owner is not found")
            self.votedAccounts[voterAddr] = (self.votedAccounts[voterAddr] ?? 0.0) + points
            self.votedNFTs[semiNFT.id] = true
        }
    }

    access(all) struct StatusLog {
        access(all)
        let status: ProposalStatus
        access(all)
        let timestamp: UFix64

        init(
            _ status: ProposalStatus,
            _ timestamp: UFix64
        ) {
            self.status = status
            self.timestamp = timestamp
        }
    }

    access(all) resource interface ProposalPublic {
        // --- Read Methods ---
        access(all) view
        fun getDetails(): ProposalDetails
        access(all) view
        fun getLogs(): [StatusLog]
        // --- Write Methods ---
        access(all)
        fun updateProposal(voter: &VoterIdentity, title: String?, message: String?, discussionLink: String?)
        access(all)
        fun cancelProposal(voter: &VoterIdentity)
    }

    /// The struct of the FixesVotes proposal.
    ///
    access(all) resource Proposal: ProposalPublic, FixesHeartbeat.IHeartbeatHook {
        access(self)
        let proposor: Address
        access(self)
        let statusLog: [StatusLog]
        access(self)
        let details: ProposalDetails

        init(
            voter: &VoterIdentity,
            tick: String,
            title: String,
            message: String,
            discussionLink: String,
            executableThreshold: UFix64,
            beginningTime: UFix64,
            endingTime: UFix64,
            slots: UInt8,
            slotsInscriptions: {UInt8: [UInt64]}
        ) {
            let voterAddr = voter.owner?.address ?? panic("Voter's owner is not found")
            let votesMgr = FRC20Votes.borrowVotesManager()
            assert(
                votesMgr.isValidProposer(addr: voterAddr),
                message: "The staked amount is not enough"
            )

            self.proposor = voterAddr
            self.statusLog = [StatusLog(ProposalStatus.Created, getCurrentBlock().timestamp)]
            self.details = ProposalDetails(
                proposer: voterAddr,
                tick: tick,
                title: title,
                message: message,
                discussionLink: discussionLink,
                executableThreshold: executableThreshold,
                beginningTime: beginningTime,
                endingTime: endingTime,
                slots: slots,
                slotsInscriptions: slotsInscriptions
            )

            emit ProposalCreated(
                proposer: voterAddr,
                tick: tick,
                proposalId: self.uuid,
                title: title,
                message: message,
                discussionLink: discussionLink,
                executableThreshold: executableThreshold,
                beginningTime: beginningTime,
                endingTime: endingTime,
                slots: slots,
                slotsInscriptions: slotsInscriptions,
            )
        }

        /** ------ Public Methods ------ */

        access(all) view
        fun getDetails(): ProposalDetails {
            return self.details
        }

        access(all) view
        fun getLogs(): [StatusLog] {
            return self.statusLog
        }

        /** ------ Private Methods ------- */

        access(all)
        fun updateProposal(voter: &VoterIdentity, title: String?, message: String?, discussionLink: String?) {
            // ensure the voter is the proposor
            assert(
                voter.owner?.address == self.proposor,
                message: "The voter is not the proposor"
            )

            self.details.updateProposal(title: title, message: message, discussionLink: discussionLink)

            emit ProposalInfoUpdated(
                proposalId: self.uuid,
                tick: self.details.tick,
                title: title,
                message: message,
                discussionLink: discussionLink
            )
        }

        /** ------ Internal Methods ------ */

        access(account)
        fun onHeartbeat(_ deltaTime: UFix64) {
            let status = self.details.getCurrentStatus()
            let lastIdx = self.statusLog.length - 1
            let lastStatus = lastIdx >= 0
                ? self.statusLog[lastIdx].status
                : nil
            if status != lastStatus {
                self.statusLog.append(StatusLog(status, getCurrentBlock().timestamp))

                emit ProposalStatusChanged(
                    proposalId: self.uuid,
                    tick: self.details.tick,
                    prevStatus: lastStatus?.rawValue,
                    newStatus: status.rawValue,
                    timestamp: getCurrentBlock().timestamp
                )
            }
        }

        access(contract)
        fun borrowDetails(): &ProposalDetails {
            return &self.details as &ProposalDetails
        }
    }

    /// The public interface of the FixesVotes manager.
    ///
    access(all) resource interface VotesManagerPublic {
        access(all) view
        fun isValidProposer(addr: Address): Bool
    }

    /// The resource of the FixesVotes manager.
    ///
    access(all) resource VotesManager: VotesManagerPublic {
        access(self)
        let whitelisted: {Address: Bool}
        access(self)
        let proposals: {String: [UInt64]}
        access(self)
        let proposalDetails: &{UInt64: Proposal}
        access(self)
        let pendingInscriptions: @{UInt64: [Fixes.Inscription]}
        access(self)
        let appliedInscriptions: @{UInt64: [Fixes.Inscription]}

        init() {
            self.whitelisted = {}
            self.proposals = {}
            self.proposalDetails = {}
            self.pendingInscriptions <- {}
            self.appliedInscriptions <- {}
        }

        /// @deprecated after Cadence 1.0
        destroy() {
            destroy self.pendingInscriptions
            destroy self.appliedInscriptions
        }

        /** ----- Read ----- */

        /// Check whether the proposer is valid.
        ///
        access(all) view
        fun isValidProposer(_ voterAddr: Address): Bool {
            if let whitelist = self.whitelisted[voterAddr] {
                if whitelist {
                    return true
                }
            }
            // check the staked amount
            let stakedAmount = FRC20Votes.getDelegatorStakedAmount(addr: voterAddr)
            let proposorThreshold = FRC20Votes.getProposorStakingThreshold()
            let totalStaked = FRC20Votes.getTotalStakedAmount()
            // ensure the staked amount is enough
            return stakedAmount >= totalStaked * proposorThreshold
        }

        access(all) view
        fun getProposalIds(tick: String): [UInt64] {
            return self.proposals[tick] ?? []
        }

        access(all) view
        fun getProposalDetails(proposalId: UInt64): Proposal? {
            return self.proposalDetails[proposalId]
        }

        /** ----- Write ----- */

        // TODO

        /** ----- Internal ----- */

        access(self)
        fun borrowProposalRef(proposalId: UInt64): &Proposal {
            return &self.proposalDetails[proposalId] as &Proposal?
                ?? panic("Proposal is not found")
        }
    }

    /* --- Public Functions --- */

    /// Get the staking ticker name.
    ///
    access(all) view
    fun getStakingTickerName(): String {
        let globalSharedStore = FRC20FTShared.borrowGlobalStoreRef()
        let stakingToken = globalSharedStore.getByEnum(FRC20FTShared.ConfigType.PlatofrmMarketplaceStakingToken) as! String?
        return stakingToken ?? "flows"
    }

    /// Get the proposor staking threshold.
    ///
    access(all) view
    fun getProposorStakingThreshold(): UFix64 {
        return 0.2
    }

    access(all) view
    fun getDelegatorStakedAmount(addr: Address): UFix64 {
        if let delegator = FRC20Staking.borrowDelegator(addr) {
            // Get the staking pool address
            let stakeTick = self.getStakingTickerName()
            return delegator.getStakedBalance(tick: stakeTick)
        }
        return 0.0
    }

    /// Create a proposal
    ///
    access(all) view
    fun getTotalStakedAmount(): UFix64 {
        let pool = self.borrowStakingPool()
        return pool.getDetails().totalStaked
    }

    /// Borrow the staking pool.
    ///
    access(all)
    fun borrowStakingPool(): &FRC20Staking.Pool{FRC20Staking.PoolPublic} {
        // singleton resources
        let acctsPool = FRC20AccountsPool.borrowAccountsPool()
        // Get the staking pool address
        let stakeTick = self.getStakingTickerName()
        let poolAddress = acctsPool.getFRC20StakingAddress(tick: stakeTick)
            ?? panic("The staking pool is not enabled")
        // borrow the staking pool
        return FRC20Staking.borrowPool(poolAddress) ?? panic("The staking pool is not found")
    }

    /// Borrow the system inscriptions store.
    ///
    access(all)
    fun borrowSystemInscriptionsStore(): &Fixes.InscriptionsStore{Fixes.InscriptionsPublic} {
        let storePubPath = Fixes.getFixesStorePublicPath()
        return self.account
            .getCapability<&Fixes.InscriptionsStore{Fixes.InscriptionsPublic}>(storePubPath)
            .borrow() ?? panic("Fixes.InscriptionsStore is not found")
    }

    /// Borrow the VotesManager resource.
    ///
    access(all)
    fun borrowVotesManager(): &VotesManager{VotesManagerPublic} {
        return self.account
            .getCapability<&VotesManager{VotesManagerPublic}>(self.FRC20VotesManagerPublicPath)
            .borrow() ?? panic("VotesManager is not found")
    }

    init() {
        let votesIdentifier = "FRC20VotesManager_".concat(self.account.address.toString())
        self.FRC20VotesManagerStoragePath = StoragePath(identifier: votesIdentifier)!
        self.FRC20VotesManagerPublicPath = PublicPath(identifier: votesIdentifier)!

        // create the resource
        self.account.save(<- create VotesManager(), to: self.FRC20VotesManagerStoragePath)
        self.account.link<&VotesManager{VotesManagerPublic}>(
            self.FRC20VotesManagerPublicPath,
            target: self.FRC20VotesManagerStoragePath
        )

        // Ensure InscriptionsStore resource
        let insStoreStoragePath = Fixes.getFixesStoreStoragePath()
        if self.account.borrow<&AnyResource>(from: insStoreStoragePath) == nil {
            self.account.save<@Fixes.InscriptionsStore>(<- Fixes.createInscriptionsStore(), to: insStoreStoragePath)
            // @deprecated after Cadence 1.0
            self.account.link<&Fixes.InscriptionsStore{Fixes.InscriptionsPublic}>(
                Fixes.getFixesStorePublicPath(),
                target: insStoreStoragePath
            )
        }

        let voterIdentifier = "FRC20Voter_".concat(self.account.address.toString())
        self.VoterStoragePath = StoragePath(identifier: voterIdentifier)!
        self.VoterPublicPath = PublicPath(identifier: voterIdentifier)!

        emit ContractInitialized()
    }
}
