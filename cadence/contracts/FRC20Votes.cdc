/**
> Author: FIXeS World <https://fixes.world/>

# FRC20Votes

TODO: Add description

*/
import "NonFungibleToken"
import "Fixes"
import "FRC20Indexer"
import "FRC20SemiNFT"

access(all) contract FRC20Votes {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /// Event emitted when a proposal is created
    access(all) event ProposalCreated(
        tick: String,
        proposalId: UInt64,
        proposer: Address,
        message: String,
        command: UInt8,
        inscriptions: [UInt64],
    )
    /// Event emitted when a proposal is voted
    access(all) event ProposalVoted(
        tick: String,
        proposalId: UInt64,
        voter: Address,
        choice: UInt8
    )
    /// Event emitted when a proposal is executed
    access(all) event ProposalExecuted(
        tick: String,
        proposalId: UInt64,
        choice: UInt8,
        executedAt: UFix64,
        success: Bool
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
        access(all) case Drafting;
        access(all) case Voting;
        access(all) case Pending;
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

    /// The struct of the FixesVotes proposal.
    ///
    access(all) struct Proposal {
        access(all)
        let proposer: Address
        access(all)
        let tick: String
        access(all)
        let message: String
        access(all)
        let slots: UInt8
        access(all)
        let slotsInscriptions: {UInt8: [UInt64]}
        access(all)
        let beginningTime: UFix64
        access(all)
        let endingTime: UFix64
        access(all)
        var votersAmt: UInt64
        access(all)
        var votes: {UInt8: UFix64}

        init(
            proposer: Address,
            tick: String,
            commandType: CommandType,
            message: String,
            beginningTime: UFix64,
            endingTime: UFix64,
            slots: UInt8,
            slotsInscriptions: {UInt8: [UInt64]}
        ) {
            pre {
                slots > 0: "Slots must be greater than 0"
            }
            self.proposer = proposer
            self.tick = tick
            self.message = message
            self.commandType = commandType
            self.slots = slots
            self.slotsInscriptions = slotsInscriptions
            self.beginningTime = beginningTime
            self.endingTime = endingTime
            self.votersAmt = 0
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

        access(all) view
        fun getCurrentStatus(): ProposalStatus {
            let now = getCurrentBlock().timestamp
            if now < self.beginningTime {
                return ProposalStatus.Drafting
            } else if now < self.endingTime {
                return ProposalStatus.Voting
            } else if self.isEnded() {
                return ProposalStatus.Pending
            } else {
                return ProposalStatus.Executed
            }
        }

        access(all) view
        fun isAnyInscriptionExecuted(): Bool {
            // TODO
            return false
        }

        /** ----- Write ----- */

        access(contract)
        fun vote(choice: UInt8, points: UFix64) {
            pre {
                self.status == ProposalStatus.Voting: "Proposal is not in voting status"
                choice < self.slots: "Choice is out of range"
                points > 0.0: "Points must be greater than 0"
                self.votingWeight[tick] != nil: "Voting weight is not found"
            }
            let weight = self.votingWeight[tick]!
            self.votes[choice] = self.votes[choice]! + weight * points
            self.votersAmt = self.votersAmt + 1
        }
    }

    /// The public interface of the FixesVotes manager.
    ///
    access(all) resource interface VotesManagerPublic {

    }

    /// The resource of the FixesVotes manager.
    ///
    access(all) resource VotesManager: VotesManagerPublic {
        access(self)
        let proposals: {String: [UInt64]}
        access(self)
        let proposalDetails: {UInt64: Proposal}
        access(self)
        let pendingInscriptions: @{UInt64: [Fixes.Inscription]}
        access(self)
        let appliedInscriptions: @{UInt64: [Fixes.Inscription]}

        init() {
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

    access(all)
    fun borrowSystemInscriptionsStore(): &Fixes.InscriptionsStore{Fixes.InscriptionsPublic} {
        let storePubPath = Fixes.getFixesStorePublicPath()
        return self.account
            .getCapability<&Fixes.InscriptionsStore{Fixes.InscriptionsPublic}>(storePubPath)
            .borrow() ?? panic("Fixes.InscriptionsStore is not found")
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
