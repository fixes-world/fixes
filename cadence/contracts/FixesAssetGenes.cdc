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
            quality: GeneQuality?,
            quantity: UInt64?
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
            self.quality = quality ?? GeneQuality.Nascent
            self.quantity = quantity ?? 0
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

        /// Get the data keys
        ///
        access(all)
        view fun getKeys(): [String] {
            return ["id", "quality", "quantity"]
        }

        /// Get the value of the data
        ///
        access(all)
        view fun getValue(_ key: String): AnyStruct? {
            if key == "id" {
                return self.getId()
            } else if key == "quality" {
                return self.quality
            } else if key == "quantity" {
                return self.quantity
            }
            return nil
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
            let newGenes: FixesAssetGenes.Gene = Gene(
                id: self.id,
                quality: self.quality, // same quality
                quantity: withdrawQuantity, // splited the quantity
            )
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
        access(all) var mutatableAmount: UInt64

        init(
            _ identifier: String,
            _ owner: Address,
            _ mutatableAmount: UInt64?
        ) {
            self.owner = owner
            self.identifier = identifier
            self.genes = {}
            self.mutatableAmount = mutatableAmount ?? 0
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

        /// Get the data keys
        ///
        access(all)
        view fun getKeys(): [String] {
            return ["identifier", "owner", "genes", "mutatableAmount"]
        }

        /// Get the value of the data
        /// It means genes keys of the DNA
        ///
        access(all)
        view fun getValue(_ key: String): AnyStruct? {
            if key == "identifier" {
                return self.identifier
            } else if key == "owner" {
                return self.owner
            } else if key == "genes" {
                return self.genes.keys
            } else if key == "mutatableAmount" {
                return self.mutatableAmount
            }
            return nil
        }

        /// Get the writable keys
        ///
        access(all)
        view fun getWritableKeys(): [String] {
            return ["mutatableAmount"]
        }

        /// Set the value of the data
        ///
        access(all)
        fun setValue(_ key: String, _ value: AnyStruct) {
            if key == "mutatableAmount" {
                self.mutatableAmount = value as! UInt64
            }
        }

        /// Split the data into another instance
        ///
        access(all)
        fun split(_ perc: UFix64): {FixesTraits.MergeableData} {
            post {
                self.getId() == result.getId(): "The result id is not the same so cannot split"
            }
            let newDna = DNA(self.identifier, self.owner, nil)
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

        // ---- Customized Methods ----

        /// Check if the DNA is mutatable
        ///
        access(all)
        view fun isMutatable(): Bool {
            return self.mutatableAmount > 0
        }

        /// Add a gene to the DNA
        ///
        access(account)
        fun addGene(_ gene: Gene): Void {
            pre {
                self.isMutatable(): "The DNA is not mutatable"
            }
            let geneId = gene.getId()
            // Merge the gene, use reference to ensure data consistency
            if let geneRef = &self.genes[geneId] as &Gene? {
                geneRef.merge(gene)
            } else {
                // If the gene is not exist, just copy it
                self.genes[geneId] = gene
            }
            // Decrease the mutatable amount
            self.mutatableAmount = self.mutatableAmount - 1
        }
    }

    /// Try mutate or generate a new gene
    ///
    access(all)
    fun attemptToGenerateGene(): Gene? {
        let randPercent = UInt8(revertibleRandom() % 100)
        // - 2%: Empowered
        // - 3%: Augmented
        // - 5%: Enhanced
        // - 7%: Basic
        // - 13%: Nascent
        // in total 30%
        if randPercent < 2 {
            let threshold = FixesAssetGenes.getQualityLevelUpThreshold(GeneQuality.Empowered)
            return Gene(id: nil, quality: GeneQuality.Empowered, quantity: revertibleRandom() % threshold)
        } else if randPercent < 5 {
            let threshold = FixesAssetGenes.getQualityLevelUpThreshold(GeneQuality.Augmented)
            return Gene(id: nil, quality: GeneQuality.Augmented, quantity: revertibleRandom() % threshold)
        } else if randPercent < 10 {
            let threshold = FixesAssetGenes.getQualityLevelUpThreshold(GeneQuality.Enhanced)
            return Gene(id: nil, quality: GeneQuality.Enhanced, quantity: revertibleRandom() % threshold)
        } else if randPercent < 17 {
            let threshold = FixesAssetGenes.getQualityLevelUpThreshold(GeneQuality.Basic)
            return Gene(id: nil, quality: GeneQuality.Basic, quantity: revertibleRandom() % threshold)
        } else if randPercent < 30 {
            let threshold = FixesAssetGenes.getQualityLevelUpThreshold(GeneQuality.Nascent)
            return Gene(id: nil, quality: GeneQuality.Nascent, quantity: revertibleRandom() % threshold)
        }
        return nil
    }
}
