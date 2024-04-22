/**

> Author: FIXeS World <https://fixes.world/>

# FixesFungibleTokenGenes

This is a sub-feature contract for Fixes Asset, which implements a way to generate on-chain genes.
It is used by all Fixes' Asset.

*/
import "FungibleToken"
import "StringUtils"
import "FixesTraits"

/// The Fixes Asset Genes contract
///
access(all) contract FixesAssetGenes {

    /// The gene quality level
    ///
    access(all) enum GeneQuality: UInt8 {
        // Quality scopes 0~4
        access(all) case Nascent
        access(all) case Basic
        access(all) case Enhanced
        access(all) case Augmented
        access(all) case Empowered
        // Quality scopes 5~9
        access(all) case Breakthrough
        access(all) case Advanced
        access(all) case Potent
        access(all) case Exemplary
        access(all) case Evolution
        // Quality scopes 10~15
        access(all) case Mystic
        access(all) case Arcane
        access(all) case Miraculous
        access(all) case Celestial
        access(all) case Cosmic
        access(all) case Eternal
    }

    /// Get the quality level up threshold
    /// @param from The quality level
    access(all)
    view fun getQualityLevelUpThreshold(_ from: GeneQuality): UInt64 {
        // The quality up threshold, using a 0~15 scale
        if from.rawValue < GeneQuality.Breakthrough.rawValue {
            // 0~4 Basic linear: Threshold = QualityLevel * 100 + 100 -> 100, 200, 300, 400, 500
            return UInt64(from.rawValue) * 100 + 100
        } else if from.rawValue < GeneQuality.Mystic.rawValue {
            // 5~9 Square: Threshold = (QualityLevel - 4) ^ 2 * 1000 + 1000 -> 2000, 5000, 10000, 17000, 26000
            let argValue = from.rawValue - GeneQuality.Empowered.rawValue
            return UInt64(argValue * argValue) * 1000 + 1000
        } else {
            // 10~15 Cubic: Threshold = (QualityLevel - 9) ^ 3 * 10000 + 20000
            let argValue = from.rawValue - GeneQuality.Evolution.rawValue
            return UInt64(argValue * argValue * argValue) * 10000 + 20000
        }
    }

    /// Get the quality level down threshold
    /// @param from The quality level
    /// @param to The quality level
    access(all)
    view fun getGeneMergeLossOrGain(_ from: GeneQuality, _ to: GeneQuality): UFix64 {
        // Larger quality level merge to lower quality level means gain rate
        // The gain rate = LevelDiff * 6% + 10%
        if from.rawValue > to.rawValue {
            let levelDiff = from.rawValue.saturatingSubtract(to.rawValue)
            return 1.1 + UFix64(levelDiff) * 0.06
        } else if from.rawValue < to.rawValue {
            // Otherwise, loss rate
            // The loss rate = LevelDiff * 3% + 5%
            let levelDiff = to.rawValue.saturatingSubtract(from.rawValue)
            return 0.95 - UFix64(levelDiff) * 0.03
        } else {
            return 1.0
        }
    }

    /// The gene data structure
    ///
    access(all) struct Gene: FixesTraits.MergeableData {
        access(all) let id: [Character;4]
        access(all) var quality: GeneQuality
        access(all) var quantity: UInt64

        init(
            id: [Character;4]?,
        ) {
            if id != nil {
                self.id = id!
            } else {
                let dnaKeys: [Character] = ["A", "C", "G", "T"]
                self.id = [
                    dnaKeys[UInt32(revertibleRandom() % 4)],
                    dnaKeys[UInt32(revertibleRandom() % 4)],
                    dnaKeys[UInt32(revertibleRandom() % 4)],
                    dnaKeys[UInt32(revertibleRandom() % 4)]
                ]
            }
            self.quality = GeneQuality.Nascent
            self.quantity = 0
        }

        /// Get the id of the data
        ///
        access(all)
        view fun getId(): String {
            return self.id[0].toString()
            .concat(self.id[1].toString())
            .concat(self.id[2].toString())
            .concat(self.id[3].toString())
        }

        /// Get the string value of the data
        ///
        access(all)
        view fun toString(): String {
            return self.getId().concat("|")
            .concat(self.quality.rawValue.toString()).concat("=")
            .concat(self.quantity.toString())
        }

        /// Get the value of the data
        ///
        access(all)
        view fun getValue(): [AnyStruct] {
            return [self.getId(), self.quality, self.quantity]
        }

        /// Split the data into another instance
        access(all)
        fun split(_ perc: UFix64): {FixesTraits.MergeableData} {
            post {
                self.getId() == result.getId(): "The gene id is not the same so cannot split"
            }
            let withdrawQuantity = UInt64(UInt128(self.quantity) * UInt128(perc * 10000.0) / 10000)
            assert(
                withdrawQuantity > 0,
                message: "The quantity to split is zero"
            )
            self.quantity = self.quantity - withdrawQuantity
            // Create a new struct
            let newGenes = Gene(id: self.id)
            newGenes.quality = self.quality // same quality
            newGenes.quantity = withdrawQuantity // splited the quantity
            return newGenes
        }

        /// Merge the data from another instance
        /// From and Self must have the same id and same type(Ensured by interface)
        ///
        access(all)
        fun merge(_ from: {FixesTraits.MergeableData}): Void {
            pre {
                self.getId() == from.getId(): "The gene id is not the same so cannot merge"
            }
            let fromGenes = from as! Gene
            let convertRate = FixesAssetGenes.getGeneMergeLossOrGain(fromGenes.quality, self.quality)
            let convertQuantity = UInt64(UInt128(fromGenes.quantity) * UInt128(convertRate * 10000.0) / 10000)
            self.quantity = self.quantity + convertQuantity

            // check if the quality can be upgraded
            var upgradeThreshold = FixesAssetGenes.getQualityLevelUpThreshold(self.quality)
            var isUpgradable = upgradeThreshold <= self.quantity && self.quality.rawValue < GeneQuality.Eternal.rawValue
            while isUpgradable {
                self.quality = GeneQuality(rawValue: self.quality.rawValue + 1)!
                self.quantity = self.quantity - upgradeThreshold
                // check upgrade again
                upgradeThreshold = FixesAssetGenes.getQualityLevelUpThreshold(self.quality)
                isUpgradable = upgradeThreshold <= self.quantity && self.quality.rawValue < GeneQuality.Eternal.rawValue
            }
        }
    }

    /// The DNA data structure
    ///
    access(all) struct DNA: FixesTraits.MergeableData {
        access(all) let identifier: String
        access(all) let owner: Address
        access(all) let genes: {String: Gene}

        init(
            _ identifier: String,
            _ owner: Address,
        ) {
            self.owner = owner
            self.identifier = identifier
            self.genes = {}
        }

        /// Get the id of the data
        ///
        access(all)
        view fun getId(): String {
            return self.identifier.concat("@").concat(self.owner.toString())
        }

        /// Get the string value of the data
        ///
        access(all)
        view fun toString(): String {
            let genes: [String] = []
            for key in self.genes.keys {
                genes.append(self.genes[key]!.toString())
            }
            return StringUtils.join(genes, ",")
        }

        /// Get the value of the data
        /// It means genes keys of the DNA
        ///
        access(all)
        view fun getValue(): [String] {
            return self.genes.keys
        }

        /// Split the data into another instance
        ///
        access(all)
        fun split(_ perc: UFix64): {FixesTraits.MergeableData} {
            post {
                self.getId() == result.getId(): "The result id is not the same so cannot split"
            }
            let newDna = DNA(self.identifier, self.owner)
            for key in self.genes.keys {
                // Split the gene, use reference to ensure data consistency
                if let geneRef = &self.genes[key] as &Gene? {
                    let geneId = geneRef.getId()
                    // add the new gene to the new DNA
                    newDna.genes[geneId] = geneRef.split(perc) as! Gene
                }
            }
            return newDna
        }

        /// Merge the data from another instance
        /// The type of the data must be the same(Ensured by interface)
        ///
        access(all)
        fun merge(_ from: {FixesTraits.MergeableData}): Void {
            let fromDna = from as! DNA
            // identifer must be the same
            assert(
                self.identifier == fromDna.identifier,
                message: "The DNA identifier is not the same so cannot merge"
            )
            for key in fromDna.genes.keys {
                if let fromGene = fromDna.genes[key] {
                    self.addGene(fromGene)
                }
            } // end for
        }

        /// Add a gene to the DNA
        ///
        access(account)
        fun addGene(_ gene: Gene): Void {
            let geneId = gene.getId()
            // Merge the gene, use reference to ensure data consistency
            if let geneRef = &self.genes[geneId] as &Gene? {
                geneRef.merge(gene)
            } else {
                // If the gene is not exist, just copy it
                self.genes[geneId] = gene
            }
        }
    }

    /// Try mutate or generate a new gene
    ///
    access(all)
    fun attemptToGenerateGene(): Gene? {
        // TODO: Implement the gene generation
        return nil
    }
}
