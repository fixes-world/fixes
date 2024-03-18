/**
> Author: FIXeS World <https://fixes.world/>

# FRC20Votes

This contract is used to manage the FRC20 votes.

*/
import "MetadataViews"
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
        slots: [ChoiceSlotDetails],
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
        choice: Int,
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
        choice: Int,
        executedAt: UFix64
    )

    /// Event emitted when the voter whitelist is updated
    access(all) event VotesManagerWhitelistUpdated(
        voter: Address,
        isWhitelisted: Bool
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
        fun getVoterAddress(): Address
        /// Get the voting power.
        access(all)
        fun getVotingPower(): UFix64
        /// Check whether the proposal is voted.
        access(all)
        fun hasVoted(proposalId: UInt64): Bool
        /// Get the voted proposals.
        access(all)
        fun getVotedProposals(tick: String): [UInt64]
        /// ---- Write: contract level ----
        access(contract)
        fun onVote(choice: Int, proposal: &Proposal{ProposalPublic})
        access(contract)
        fun onProposalFinalized(proposal: &Proposal{ProposalPublic})
    }

    /// The resource of the FixesVotes voter identifier.
    ///
    access(all) resource VoterIdentity: VoterPublic, FRC20SemiNFT.FRC20SemiNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        access(self)
        let semiNFTColCap: Capability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>
        access(self)
        let lockedSemiNFTCollection: @FRC20SemiNFT.Collection
        // ----- Voting Info ----
        /// Voted proposal id -> Points
        access(self)
        let voted: {UInt64: Bool}
        /// Tick -> ProposalId[]
        access(self)
        let votedTicksMapping: {String: [UInt64]}
        /// ProposalID -> EndedAt
        access(self)
        let activeProposals: {UInt64: UFix64}

        init(
            _ cap: Capability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>
        ) {
            pre {
                cap.check(): "The capability is invalid"
            }
            self.semiNFTColCap = cap
            self.lockedSemiNFTCollection <- (FRC20SemiNFT.createEmptyCollection() as! @FRC20SemiNFT.Collection)
            self.voted = {}
            self.votedTicksMapping = {}
            self.activeProposals = {}
        }

        destroy() {
            destroy self.lockedSemiNFTCollection
        }
        /** ----- Implement NFT Standard ----- */

        access(all)
        fun deposit(token: @NonFungibleToken.NFT) {
            self.lockedSemiNFTCollection.deposit(token: <- token)
        }

        access(all)
        fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            return <- self.lockedSemiNFTCollection.withdraw(withdrawID: withdrawID)
        }

        access(all)
        fun getIDs(): [UInt64] {
            return self.lockedSemiNFTCollection.getIDs()
        }

        access(all)
        fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return self.lockedSemiNFTCollection.borrowNFT(id: id)
        }

        access(all)
        fun borrowNFTSafe(id: UInt64): &NonFungibleToken.NFT? {
            return self.lockedSemiNFTCollection.borrowNFTSafe(id: id)
        }

        access(all) view
        fun getIDsByTick(tick: String): [UInt64] {
            return self.lockedSemiNFTCollection.getIDsByTick(tick: tick)
        }

        access(all) view
        fun getStakedBalance(tick: String): UFix64 {
            return self.lockedSemiNFTCollection.getStakedBalance(tick: tick)
        }

        access(all)
        fun borrowFRC20SemiNFTPublic(id: UInt64): &FRC20SemiNFT.NFT{FRC20SemiNFT.IFRC20SemiNFT, NonFungibleToken.INFT, MetadataViews.Resolver}? {
            return self.lockedSemiNFTCollection.borrowFRC20SemiNFTPublic(id: id)
        }

        /** ----- Read ----- */

        /// Get the voter address.
        ///
        access(all)
        fun getVoterAddress(): Address {
            return self.owner?.address ?? panic("Voter's owner is not found")
        }

        /// Get the voting power.
        ///
        access(all)
        fun getVotingPower(): UFix64 {
            let stakeTick = FRC20Votes.getStakingTickerName()
            let selfAddr = self.getVoterAddress()

            var power = 0.0
            if let delegator = FRC20Staking.borrowDelegator(selfAddr) {
                // Get the staking pool address
                power = delegator.getStakedBalance(tick: stakeTick)
            }
            return power + self.getStakedBalance(tick: stakeTick)
        }

        /// Check whether the proposal is voted.
        ///
        access(all)
        fun hasVoted(proposalId: UInt64): Bool {
            return self.voted[proposalId] != nil
        }

        /// Get the voted proposals.
        ///
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
        fun onVote(choice: Int, proposal: &Proposal{ProposalPublic}) {
            pre {
                self.voted[proposal.uuid] == false: "Proposal is already voted"
            }
            post {
                self.voted[proposal.uuid] == true: "Proposal is not voted"
            }
            let details = proposal.getDetails()

            // check the staked balance
            let stakeTick = FRC20Votes.getStakingTickerName()
            let stakedBalance = self.getStakedBalance(tick: stakeTick)
            if stakedBalance > 0.0 {
                let stakedNFTColRef = self.semiNFTColCap.borrow() ?? panic("The staked NFT collection is not found")
                // move the staked NFTs to the locked collection
                let ids = stakedNFTColRef.getIDsByTick(tick: stakeTick)
                for id in ids {
                    self.lockedSemiNFTCollection.deposit(token: <- stakedNFTColRef.withdraw(withdrawID: id))
                }
            }

            // check staked balance
            let votingPower = self.getVotingPower()
            assert(
                votingPower > 0.0,
                message: "The voting power is zero"
            )

            // vote on the proposal
            let lockedNFTIds = self.lockedSemiNFTCollection.getIDsByTick(tick: stakeTick)
            for id in lockedNFTIds {
                let semiNFT = self.lockedSemiNFTCollection.borrowFRC20SemiNFTPublic(id: id)
                    ?? panic("The semiNFT is not found")
                if !proposal.isVoted(semiNFT) {
                    proposal.vote(choice: choice, semiNFT: semiNFT)
                }
            }

            // update the local voting status
            self.voted[proposal.uuid] = true
            if self.votedTicksMapping[details.tick] == nil {
                self.votedTicksMapping[details.tick] = [proposal.uuid]
            } else {
                self.votedTicksMapping[details.tick]?.append(proposal.uuid)
            }
            // add the proposal to the locking queue
            self.activeProposals[proposal.uuid] = details.endingTime
        }

        access(contract)
        fun onProposalFinalized(proposal: &Proposal{ProposalPublic}) {
            if !proposal.isFinalized() {
                return
            }
            // remove the proposal from the locking queue
            self.activeProposals.remove(key: proposal.uuid)

            // check is no more active proposals
            if self.activeProposals.keys.length == 0 {
                // return all the staked NFTs to the staked collection
                let stakeTick = FRC20Votes.getStakingTickerName()
                let lockedNFTIds = self.lockedSemiNFTCollection.getIDsByTick(tick: stakeTick)
                if let semiNFTColRef = self.semiNFTColCap.borrow() {
                    for id in lockedNFTIds {
                        semiNFTColRef.deposit(token: <- self.lockedSemiNFTCollection.withdraw(withdrawID: id))
                    }
                }
            }
        }
    }
    /// The struct of the FixesVotes proposal choice slot details.
    ///
    access(all) struct ChoiceSlotDetails {
        access(all)
        let message: String
        access(all)
        let inscriptions: [UInt64]

        init(
            message: String,
            inscriptions: [UInt64]
        ) {
            self.message = message
            self.inscriptions = inscriptions
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
        let slots: [ChoiceSlotDetails]
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

        init(
            proposer: Address,
            tick: String,
            title: String,
            message: String,
            discussionLink: String,
            executableThreshold: UFix64,
            beginningTime: UFix64,
            endingTime: UFix64,
            slots: [ChoiceSlotDetails]
        ) {
            pre {
                slots.length > 0: "Slots must be greater than 0"
                executableThreshold >= 0.1 && executableThreshold <= 0.8: "Executable threshold must be between 0.1 and 0.8"
                beginningTime < endingTime: "Beginning time must be less than ending time"
            }
            self.proposer = proposer
            self.tick = tick
            self.title = title
            self.message = message
            self.discussionLink = discussionLink
            self.slots = slots
            self.beginningTime = beginningTime
            self.endingTime = endingTime
            self.executableThreshold = executableThreshold
            self.isCancelled = false
        }

        /** ----- Read ----- */

        access(all) view
        fun isStarted(): Bool {
            return self.beginningTime <= getCurrentBlock().timestamp
        }

        /// The Proposal is ended if the endAt is not nil.
        ///
        access(all) view
        fun isEnded(): Bool {
            return self.endingTime <= getCurrentBlock().timestamp
        }

        /** ----- Write ----- */

        access(contract)
        fun updateProposal(title: String?, message: String?, discussionLink: String?) {
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
                self.isCancelled == false: "Proposal is already cancelled"
            }
            self.isCancelled = true
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
        fun isEditable(): Bool
        access(all) view
        fun isFinalized(): Bool
        access(all) view
        fun getStatus(): ProposalStatus
        access(all) view
        fun getDetails(): ProposalDetails
        access(all) view
        fun getLogs(): [StatusLog]
        access(all) view
        fun getVotersAmount(): Int
        access(all) view
        fun getVoters(): [Address]
        access(all) view
        fun getTotalVotedPoints(): UFix64
        access(all) view
        fun getWinningChoice(): Int?
        access(all) view
        fun isValidateForThreshold(): Bool
        access(all) view
        fun isWinningInscriptionAllExecuted(): Bool
        access(all) view
        fun isVoted(_ semiNFT: &FRC20SemiNFT.NFT{FRC20SemiNFT.IFRC20SemiNFT}): Bool
        // --- Write Methods ---
        access(contract)
        fun vote(choice: Int, semiNFT: &FRC20SemiNFT.NFT{FRC20SemiNFT.IFRC20SemiNFT})
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
        // ----- Voting status -----
        /// Address -> Points
        access(self)
        var votedAccounts: {Address: UFix64}
        /// NFTId -> Bool
        access(self)
        var votedNFTs: {UInt64: Bool}
        /// Vote choice -> Points
        access(self)
        var votes: {Int: UFix64}

        init(
            voter: Address,
            tick: String,
            title: String,
            message: String,
            discussionLink: String,
            executableThreshold: UFix64,
            beginningTime: UFix64,
            endingTime: UFix64,
            slots: [ChoiceSlotDetails],
        ) {
            self.proposor = voter
            self.statusLog = [StatusLog(ProposalStatus.Created, getCurrentBlock().timestamp)]
            self.details = ProposalDetails(
                proposer: voter,
                tick: tick,
                title: title,
                message: message,
                discussionLink: discussionLink,
                executableThreshold: executableThreshold,
                beginningTime: beginningTime,
                endingTime: endingTime,
                slots: slots,
            )
            self.votedAccounts = {}
            self.votedNFTs = {}
            // init votes
            self.votes = {}
            var i = 0
            while i < slots.length {
                self.votes[i] = 0.0
                i = i + 1
            }

            emit ProposalCreated(
                proposer: voter,
                tick: tick,
                proposalId: self.uuid,
                title: title,
                message: message,
                discussionLink: discussionLink,
                executableThreshold: executableThreshold,
                beginningTime: beginningTime,
                endingTime: endingTime,
                slots: slots,
            )
        }

        /** ------ Public Methods ------ */

        access(all) view
        fun isEditable(): Bool {
            let status = self.getStatus()
            return status == ProposalStatus.Created || status == ProposalStatus.Activated
        }

        access(all) view
        fun isFinalized(): Bool {
            let status = self.getStatus()
            return status == ProposalStatus.Failed || status == ProposalStatus.Cancelled || status == ProposalStatus.Executed
        }

        /// Get current status.
        ///
        access(all) view
        fun getStatus(): ProposalStatus {
            let now = getCurrentBlock().timestamp
            if self.details.isCancelled {
                return ProposalStatus.Cancelled
            } else if now < self.details.beginningTime {
                return ProposalStatus.Created
            } else if now < self.details.endingTime {
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
        fun getDetails(): ProposalDetails {
            return self.details
        }

        access(all) view
        fun getLogs(): [StatusLog] {
            return self.statusLog
        }

        /// Get the voters amount.
        ///
        access(all) view
        fun getVotersAmount(): Int {
            return self.votedAccounts.keys.length
        }

        /// Get the voters.
        ///
        access(all) view
        fun getVoters(): [Address] {
            return self.votedAccounts.keys
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
        fun getWinningChoice(): Int? {
            if !self.details.isEnded() {
                return nil
            }
            // get the winning choice
            var winningChoice = 0
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
            if !self.details.isEnded() {
                return false
            }
            let totalStaked = FRC20Votes.getTotalStakedAmount()
            let votedAmount = self.getTotalVotedPoints()
            return totalStaked * self.details.executableThreshold <= votedAmount
        }

        access(all) view
        fun isWinningInscriptionAllExecuted(): Bool {
            if !self.details.isEnded() {
                return false
            }
            if let winningChoice = self.getWinningChoice() {
                let slotInfoRef = self.details.slots[winningChoice]
                let winningInsIds = slotInfoRef.inscriptions
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

        /** ------ Write Methods: Contract ------ */

        /// Vote on a proposal.
        ///
        access(contract)
        fun vote(choice: Int, semiNFT: &FRC20SemiNFT.NFT{FRC20SemiNFT.IFRC20SemiNFT}) {
            pre {
                self.details.isStarted(): "Proposal is not started"
                !self.details.isEnded(): "Proposal is ended"
                choice < self.details.slots.length: "Choice is out of range"
                semiNFT.getOriginalTick() == FRC20Votes.getStakingTickerName(): "The ticker is not the staking ticker"
                semiNFT.isStakedTick(): "The ticker is not staked"
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

            emit ProposalVoted(
                tick: self.details.tick,
                proposalId: self.uuid,
                voter: semiNFT.owner?.address ?? panic("Voter's owner is not found"),
                choice: choice,
                points: semiNFT.getBalance()
            )
        }

        /** ------ Internal Methods: Implement Heartbeat ------ */

        /// Implement the heartbeat hook.
        ///
        access(account)
        fun onHeartbeat(_ deltaTime: UFix64) {
            let status = self.getStatus()
            let lastIdx = self.statusLog.length - 1
            let lastStatus = lastIdx >= 0
                ? self.statusLog[lastIdx].status
                : nil

            if status != lastStatus {
                let now = getCurrentBlock().timestamp
                self.statusLog.append(StatusLog(status, now))

                // emit event
                emit ProposalStatusChanged(
                    proposalId: self.uuid,
                    tick: self.details.tick,
                    prevStatus: lastStatus?.rawValue,
                    newStatus: status.rawValue,
                    timestamp: now
                )

                // invoke onProposalFinalized in voters
                if self.isFinalized() {
                    let allVoters = self.getVoters()
                    for addr in allVoters {
                        if let voterRef = FRC20Votes.borrowVoterPublic(addr) {
                            voterRef.onProposalFinalized(proposal: &self as &Proposal{ProposalPublic})
                        }
                    }
                }

                // check the status and do the action
                switch status {
                case ProposalStatus.Failed:
                    // emit event
                    emit ProposalFailed(
                        tick: self.details.tick,
                        proposalId: self.uuid,
                        votedPoints: self.getTotalVotedPoints(),
                        failedAt: now
                    )
                case ProposalStatus.Executed:
                    // emit event
                    emit ProposalExecuted(
                        tick: self.details.tick,
                        proposalId: self.uuid,
                        choice: self.getWinningChoice()!,
                        executedAt: now
                    )
                }
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
        /// Check whether the proposer is valid.
        access(all) view
        fun isValidProposer(_ voterAddr: Address): Bool
        /** ------ Proposal Getter ------ */
        access(all) view
        fun getProposalLength(): Int
        access(all) view
        fun getProposalIds(): [UInt64]
        access(all) view
        fun getActiveProposalIds(): [UInt64]
        access(all) view
        fun getProposalIdsByTick(tick: String): [UInt64]
        /// Borrow the proposal.
        access(all)
        fun borrowProposal(_ proposalId: UInt64): &Proposal{ProposalPublic}?
        /** ------ Write Methods ------ */
        /// Create a new proposal.
        access(all)
        fun createProposal(
            voter: &VoterIdentity,
            tick: String,
            title: String,
            message: String,
            discussionLink: String,
            executableThreshold: UFix64,
            beginningTime: UFix64,
            endingTime: UFix64,
            messages: [String],
            inscriptions: @[[Fixes.Inscription]]
        )
        /// Vote on a proposal.
        access(all)
        fun vote(
            voter: &VoterIdentity,
            proposalId: UInt64,
            choice: Int,
        )
        // --- Write Methods: Proposer ---
        access(all)
        fun updateProposal(voter: &VoterIdentity, proposalId: UInt64, title: String?, message: String?, discussionLink: String?)
        access(all)
        fun cancelProposal(voter: &VoterIdentity, proposalId: UInt64)
    }

    /// The resource of the FixesVotes manager.
    ///
    access(all) resource VotesManager: VotesManagerPublic, FixesHeartbeat.IHeartbeatHook {
        /// Voter -> Bool
        access(self)
        let whitelisted: {Address: Bool}
        /// ProposalId -> Proposal
        access(self)
        let proposals: @{UInt64: Proposal}
        /// active proposal ids
        access(self)
        let activeProposalIds: [UInt64]
        /// Ticker -> ProposalId[]
        access(self)
        let proposalIdsByTick: {String: [UInt64]}

        init() {
            self.whitelisted = {}
            self.proposals <- {}
            self.activeProposalIds = []
            self.proposalIdsByTick = {}
        }

        /// @deprecated after Cadence 1.0
        destroy() {
            destroy self.proposals
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
            if let voter = FRC20Votes.borrowVoterPublic(voterAddr) {
                // check the staked amount
                let proposorThreshold = FRC20Votes.getProposorStakingThreshold()
                let totalStaked = FRC20Votes.getTotalStakedAmount()
                // ensure the staked amount is enough
                return voter.getVotingPower() >= totalStaked * proposorThreshold
            }
            return false
        }

        access(all) view
        fun getProposalLength(): Int {
            return self.proposals.keys.length
        }

        access(all) view
        fun getProposalIds(): [UInt64] {
            return self.proposals.keys
        }

        access(all) view
        fun getActiveProposalIds(): [UInt64] {
            return self.activeProposalIds
        }

        access(all) view
        fun getProposalIdsByTick(tick: String): [UInt64] {
            return self.proposalIdsByTick[tick] ?? []
        }

        access(all)
        fun borrowProposal(_ proposalId: UInt64): &Proposal{ProposalPublic}? {
            return self.borrowProposalRef(proposalId)
        }

        /** ----- Write ----- */

        /// Create a new proposal.
        ///
        access(all)
        fun createProposal(
            voter: &VoterIdentity,
            tick: String,
            title: String,
            message: String,
            discussionLink: String,
            executableThreshold: UFix64,
            beginningTime: UFix64,
            endingTime: UFix64,
            messages: [String],
            inscriptions: @[[Fixes.Inscription]]
        ) {
            pre {
                beginningTime < endingTime: "Beginning time must be less than ending time"
                messages.length > 0: "Messages must be greater than 0"
                messages.length == inscriptions.length: "Messages and inscriptions must be the same length"
            }
            let voterAddr = voter.owner?.address ?? panic("Voter's owner is not found")
            assert(
                self.isValidProposer(voterAddr),
                message: "The staked amount is not enough"
            )

            // Save the inscriptions
            let inscriptionsStore = FRC20Votes.borrowSystemInscriptionsStore()
            let slots: [ChoiceSlotDetails] = []

            let slotsLen = inscriptions.length
            var i = 0
            while i < slotsLen {
                let insList <- inscriptions.removeFirst()
                let insIds: [UInt64] = []

                let insListLen = insList.length
                var j = 0
                while j < insListLen {
                    let ins <- insList.removeFirst()
                    insIds.append(ins.getId())
                    inscriptionsStore.store(<- ins)
                    j = j + 1
                }
                destroy insList

                slots.append(ChoiceSlotDetails(
                    message: messages[i],
                    inscriptions: insIds
                ))
                i = i + 1
            }
            destroy inscriptions

            let proposal <- create Proposal(
                voter: voterAddr,
                tick: tick,
                title: title,
                message: message,
                discussionLink: discussionLink,
                executableThreshold: executableThreshold,
                beginningTime: beginningTime,
                endingTime: endingTime,
                slots: slots
            )
            let proposalId = proposal.uuid
            self.proposals[proposalId] <-! proposal
            // update proposalIds by tick
            if self.proposalIdsByTick[tick] == nil {
                self.proposalIdsByTick[tick] = [proposalId]
            } else {
                self.proposalIdsByTick[tick]?.append(proposalId)
            }
            // insert activeProposalIds
            self.activeProposalIds.insert(at: 0, proposalId)
        }

        access(all)
        fun vote(
            voter: &VoterIdentity,
            proposalId: UInt64,
            choice: Int,
        ) {
            let proposalRef = self.borrowProposal(proposalId)
                ?? panic("The proposal is not found")
            voter.onVote(choice: choice, proposal: proposalRef)
        }

        // --- Write Methods: Proposor ---

        /** ------ Private Methods ------- */

        /// Update the proposal.
        ///
        access(all)
        fun updateProposal(voter: &VoterIdentity, proposalId: UInt64, title: String?, message: String?, discussionLink: String?) {
            let proposalRef = self.borrowProposalRef(proposalId)
                ?? panic("The proposal is not found")
            let detailsRef = proposalRef.borrowDetails()
            assert(
                detailsRef.proposer == voter.owner?.address,
                message: "The voter is not the proposor"
            )
            assert(
                proposalRef.isEditable(),
                message: "The proposal is not editable"
            )
            detailsRef.updateProposal(title: title, message: message, discussionLink: discussionLink)

            emit ProposalInfoUpdated(
                proposalId: proposalRef.uuid,
                tick: detailsRef.tick,
                title: title,
                message: message,
                discussionLink: discussionLink
            )
        }

        /// Cancel the proposal.
        ///
        access(all)
        fun cancelProposal(voter: &VoterIdentity, proposalId: UInt64) {
            let proposalRef = self.borrowProposalRef(proposalId)
                ?? panic("The proposal is not found")
            let detailsRef = proposalRef.borrowDetails()
            assert(
                detailsRef.proposer == voter.owner?.address,
                message: "The voter is not the proposor"
            )
            assert(
                proposalRef.isEditable(),
                message: "The proposal is not editable"
            )
            detailsRef.cancelProposal()

            emit ProposalCancelled(
                proposalId: self.uuid,
                tick: detailsRef.tick
            )
        }

        /** ----- Write: Private ----- */

        access(all)
        fun updateWhitelist(voter: Address, isWhitelisted: Bool) {
            self.whitelisted[voter] = isWhitelisted
            emit VotesManagerWhitelistUpdated(voter: voter, isWhitelisted: isWhitelisted)
        }

        /** ------ Internal Methods ------ */

        access(account)
        fun onHeartbeat(_ deltaTime: UFix64) {
            // update the active proposal ids
            var i = 0
            while i < self.activeProposalIds.length {
                let proposalId = self.activeProposalIds.removeFirst()
                if let proposal = self.borrowProposalRef(proposalId) {
                    // call the proposal heartbeat
                    proposal.onHeartbeat(deltaTime)

                    // check if finalized
                    if !proposal.isFinalized() {
                        // re-insert the proposal id
                        self.activeProposalIds.append(proposalId)
                    }
                }
                i = i + 1
            }
        }

        /** ----- Internal ----- */

        access(self)
        fun borrowProposalRef(_ proposalId: UInt64): &Proposal? {
            return &self.proposals[proposalId] as &Proposal?
        }
    }

    /* --- Public Functions --- */

    access(all)
    fun createVoter(
        _ cap: Capability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>
    ): @VoterIdentity {
        return <- create VoterIdentity(cap)
    }

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
        return 0.15
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
    fun borrowSystemInscriptionsStore(): &Fixes.InscriptionsStore{Fixes.InscriptionsStorePublic, Fixes.InscriptionsPublic} {
        let storePubPath = Fixes.getFixesStorePublicPath()
        return self.account
            .getCapability<&Fixes.InscriptionsStore{Fixes.InscriptionsStorePublic, Fixes.InscriptionsPublic}>(storePubPath)
            .borrow() ?? panic("Fixes.InscriptionsStore is not found")
    }

    /// Borrow the voter resource.
    ///
    access(all)
    fun borrowVoterPublic(_ addr: Address): &VoterIdentity{VoterPublic, FRC20SemiNFT.FRC20SemiNFTCollectionPublic, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}? {
        return getAccount(addr)
            .getCapability<&VoterIdentity{VoterPublic, FRC20SemiNFT.FRC20SemiNFTCollectionPublic, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>(self.VoterPublicPath)
            .borrow()
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
        self.account.link<&VotesManager{VotesManagerPublic, FixesHeartbeat.IHeartbeatHook}>(
            self.FRC20VotesManagerPublicPath,
            target: self.FRC20VotesManagerStoragePath
        )

        // Register to FixesHeartbeat
        let heartbeatScope = "FRC20Votes"
        let accountAddr = self.account.address
        if !FixesHeartbeat.hasHook(scope: heartbeatScope, hookAddr: accountAddr) {
            FixesHeartbeat.addHook(
                scope: heartbeatScope,
                hookAddr: accountAddr,
                hookPath: self.FRC20VotesManagerPublicPath
            )
        }

        // Ensure InscriptionsStore resource
        let insStoreStoragePath = Fixes.getFixesStoreStoragePath()
        if self.account.borrow<&AnyResource>(from: insStoreStoragePath) == nil {
            self.account.save<@Fixes.InscriptionsStore>(<- Fixes.createInscriptionsStore(), to: insStoreStoragePath)
        }
        let insStorePubPath = Fixes.getFixesStorePublicPath()
        // @deprecated after Cadence 1.0
        if !self.account
            .getCapability<&Fixes.InscriptionsStore{Fixes.InscriptionsStorePublic, Fixes.InscriptionsPublic}>(insStorePubPath)
            .check() {
            self.account.unlink(insStorePubPath)
            self.account.link<&Fixes.InscriptionsStore{Fixes.InscriptionsStorePublic, Fixes.InscriptionsPublic}>(
                insStorePubPath,
                target: insStoreStoragePath
            )
        }

        let voterIdentifier = "FRC20Voter_".concat(self.account.address.toString())
        self.VoterStoragePath = StoragePath(identifier: voterIdentifier)!
        self.VoterPublicPath = PublicPath(identifier: voterIdentifier)!

        emit ContractInitialized()
    }
}
