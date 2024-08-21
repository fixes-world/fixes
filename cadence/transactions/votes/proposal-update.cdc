import "FlowToken"
import "FungibleToken"
import "NonFungibleToken"
import "MetadataViews"
import "Fixes"
import "FRC20SemiNFT"
import "FRC20Votes"

transaction(
    proposalId: UInt64,
    title: String?,
    description: String?,
    discussionLink: String?,
) {
    let voter: auth(NonFungibleToken.Withdraw) &FRC20Votes.VoterIdentity

    prepare(acct: auth(Storage, Capabilities) &Account) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.storage.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        /** ------------- Start -- FRC20 Semi NFT Collection Initialization ------------  */
        // ensure resource
        if acct.storage.borrow<&AnyResource>(from: FRC20SemiNFT.CollectionStoragePath) == nil {
            acct.storage.save(<- FRC20SemiNFT.createEmptyCollection(nftType: Type<@FRC20SemiNFT.NFT>()), to: FRC20SemiNFT.CollectionStoragePath)
        }

        // link to public capability
        if acct
            .capabilities.get<&FRC20SemiNFT.Collection>(FRC20SemiNFT.CollectionPublicPath)
            .borrow() == nil {
            acct.capabilities.unpublish(FRC20SemiNFT.CollectionPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20SemiNFT.Collection>(
                    FRC20SemiNFT.CollectionStoragePath
                ),
                at: FRC20SemiNFT.CollectionPublicPath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        /** ------------- Initialize Voter Resource - Start -------------------- */
        if acct.storage.borrow<&AnyResource>(from: FRC20Votes.VoterStoragePath) == nil {
            // get private cap
            let cap = acct.capabilities.storage
                .issue<auth(NonFungibleToken.Withdraw, NonFungibleToken.Update) &FRC20SemiNFT.Collection>(FRC20SemiNFT.CollectionStoragePath)
            acct.storage.save(<- FRC20Votes.createVoter(cap), to: FRC20Votes.VoterStoragePath)
        }

        // link to public capability
        if acct
            .capabilities
            .get<&FRC20Votes.VoterIdentity>(FRC20Votes.VoterPublicPath)
            .borrow() == nil {
            acct.capabilities.unpublish(FRC20Votes.VoterPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20Votes.VoterIdentity>(
                    FRC20Votes.VoterStoragePath
                ),
                at: FRC20Votes.VoterPublicPath
            )
        }
        /** ------------- End -------------------------------------------------- */

        self.voter = acct.storage.borrow<auth(NonFungibleToken.Withdraw) &FRC20Votes.VoterIdentity>(from: FRC20Votes.VoterStoragePath)
            ?? panic("Could not borrow a reference to the Voter Resource!")
    }

    execute {
        // Singleton Resources
        let voteMgr = FRC20Votes.borrowVotesManager()
        voteMgr.updateProposal(
            voter: self.voter,
            proposalId: proposalId,
            title: title,
            description: description,
            discussionLink: discussionLink
        )
    }
}
