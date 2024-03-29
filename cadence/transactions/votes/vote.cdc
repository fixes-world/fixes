import "FlowToken"
import "FungibleToken"
import "NonFungibleToken"
import "MetadataViews"
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20SemiNFT"
import "FRC20Votes"
import "FRC20VoteCommands"

transaction(
    proposalId: UInt64,
    choice: Int,
) {
    let voter: &FRC20Votes.VoterIdentity

    prepare(acct: AuthAccount) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        /** ------------- Start -- FRC20 Semi NFT Collection Initialization ------------  */
        // ensure resource
        if acct.borrow<&AnyResource>(from: FRC20SemiNFT.CollectionStoragePath) == nil {
            acct.save(<- FRC20SemiNFT.createEmptyCollection(), to: FRC20SemiNFT.CollectionStoragePath)
        }

        // link to public capability
        // @deprecated after Cadence 1.0
        if acct
            .getCapability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPublicPath)
            .borrow() == nil {
            acct.unlink(FRC20SemiNFT.CollectionPublicPath)
            acct.link<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(
                FRC20SemiNFT.CollectionPublicPath,
                target: FRC20SemiNFT.CollectionStoragePath
            )
            // Link private path (will be deprecated in Cadence 1.0)
            acct.unlink(FRC20SemiNFT.CollectionPrivatePath)
            acct.link<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
                FRC20SemiNFT.CollectionPrivatePath,
                target: FRC20SemiNFT.CollectionStoragePath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        /** ------------- Initialize Voter Resource - Start -------------------- */
        if acct.borrow<&AnyResource>(from: FRC20Votes.VoterStoragePath) == nil {
            // get private cap
            let cap = acct.getCapability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPrivatePath)
            acct.save(<- FRC20Votes.createVoter(cap), to: FRC20Votes.VoterStoragePath)
        }

        // link to public capability
        // @deprecated after Cadence 1.0
        if acct
            .getCapability<&FRC20Votes.VoterIdentity{FRC20Votes.VoterPublic}>(FRC20Votes.VoterPublicPath)
            .borrow() == nil {
            acct.unlink(FRC20Votes.VoterPublicPath)
            acct.link<&FRC20Votes.VoterIdentity{FRC20Votes.VoterPublic, FRC20SemiNFT.FRC20SemiNFTCollectionPublic, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic}>(
                FRC20Votes.VoterPublicPath,
                target: FRC20Votes.VoterStoragePath
            )
        }
        /** ------------- End -------------------------------------------------- */

        self.voter = acct.borrow<&FRC20Votes.VoterIdentity>(from: FRC20Votes.VoterStoragePath)
            ?? panic("Could not borrow a reference to the Voter Resource!")
    }

    execute {
        // Singleton Resources
        let voteMgr = FRC20Votes.borrowVotesManager()
        voteMgr.vote(voter: self.voter, proposalId: proposalId, choice: choice)
    }
}
