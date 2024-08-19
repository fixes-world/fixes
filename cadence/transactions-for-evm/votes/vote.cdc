import "FlowToken"
import "FungibleToken"
import "NonFungibleToken"
import "MetadataViews"
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20SemiNFT"
import "FRC20Votes"
import "FRC20VoteCommands"
import "EVMAgent"

transaction(
    proposalId: UInt64,
    choice: Int,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    let voter: &FRC20Votes.VoterIdentity

    prepare(signer: auth(Storage, Capabilities) &Account) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "vote(UInt64|Int)",
            params: [proposalId.toString(), choice.toString()],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */

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

        self.voter = acct.storage.borrow<&FRC20Votes.VoterIdentity>(from: FRC20Votes.VoterStoragePath)
            ?? panic("Could not borrow a reference to the Voter Resource!")
    }

    execute {
        // Singleton Resources
        let voteMgr = FRC20Votes.borrowVotesManager()
        voteMgr.vote(voter: self.voter, proposalId: proposalId, choice: choice)
    }
}
