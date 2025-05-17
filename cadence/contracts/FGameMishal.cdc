/**
> Author: Fixes Lab <https://github.com/fixes-world/>

# FGameMishal

This contract is used to define the basic game elements.
The basic elements of a Mishal Game will be defined here.

*/
import "Burner"
// Fixes Imports
import "Fixes"
import "FixesHeartbeat"

access(all) contract FGameMishal {
    // Entitlements for the Editor role
    access(all) entitlement Editor;
    // Entitlements for the Manage role (Like the host of the game)
    access(all) entitlement Manage;

    // ----- Events -----

    access(all) event LibrarySettingChanged(_ library: Address, key: UInt8, value: Int64)
    access(all) event LibraryEntryAdded(_ library: Address, _ category: UInt8, _ uuid: UInt64, _ name: String, _ tags: [String])
    access(all) event LibraryEntryRemoved(_ library: Address, _ category: UInt8, _ uuid: UInt64)

    // ----- Contract Level Variables -----

    // The counter variable for the library items
    access(all) let libraryItems: {Address: UInt64}

    access(all) let libraryStoragePath: StoragePath
    access(all) let libraryPublicPath: PublicPath

    // ----- Resources -----

    access(all) enum LibrarySettings: UInt8 {
        access(all) case INIT_POTENTIALITY
    }

    access(all) enum LibraryCategory: UInt8 {
        access(all) case OBJECT
        access(all) case ITEM
        access(all) case ABILITY
        access(all) case SHAPE
        access(all) case FEATURE
        access(all) case CREATURE
    }

    access(all) enum EquipSlot: UInt8 {
        access(all) case WEAPONS // 武器
        access(all) case HEAD // 头饰
        access(all) case ARMOR // 盔甲
        access(all) case FEET // 鞋子
        access(all) case HARNESS // 马具
        access(all) case EARRINGS // 耳饰
        access(all) case NECK // 项链
        access(all) case RINGS // 戒指
        access(all) case WRISTS // 手镯
        access(all) case GLOVES // 手套
        access(all) case FOOTWEAR // 足饰
        access(all) case BELT // 腰饰
        access(all) case TAIL // 尾饰
        access(all) case SHAWL // 披肩
        access(all) case COAT // 服装
        access(all) case MAKEUP // 妆饰
        access(all) case ACCESSORY // 配饰
    }

    access(all) enum CreatureSettings: UInt8 {
        access(all) case GENDER
        access(all) case FORM
        access(all) case SIZE
        access(all) case MOVE_SPEED
        access(all) case PERCEPTION_RANGE
        access(all) case OCCUPY_RANGE
    }

    // The Public Library resource is used to store the settings of Mishal Game.
    access(all) resource Library {
        access(all) let settings: {LibrarySettings: Int64}
        access(all) let objects: @{UInt64: Object}
        access(all) let items: @{UInt64: Item}
        access(all) let abilities: @{UInt64: Ability}
        access(all) let shapes: @{UInt64: Shape}
        access(all) let features: @{UInt64: Feature}
        access(all) let creatures: @{UInt64: Creature}
        access(self) let nameToUID: {LibraryCategory: {String: UInt64}}
        access(self) let tagToUIDs: {LibraryCategory: {String: [UInt64]}}

        init() {
            self.settings = {
                LibrarySettings.INIT_POTENTIALITY: 36
            }
            self.objects <- {}
            self.items <- {}
            self.abilities <- {}
            self.shapes <- {}
            self.features <- {}
            self.creatures <- {}
            self.nameToUID = {}
            self.tagToUIDs = {}

            // initialize the nameToUID and tagToUIDs
            self.nameToUID[LibraryCategory.OBJECT] = {}
            self.nameToUID[LibraryCategory.ITEM] = {}
            self.nameToUID[LibraryCategory.ABILITY] = {}
            self.nameToUID[LibraryCategory.SHAPE] = {}
            self.nameToUID[LibraryCategory.FEATURE] = {}
            self.nameToUID[LibraryCategory.CREATURE] = {}

            self.tagToUIDs[LibraryCategory.OBJECT] = {}
            self.tagToUIDs[LibraryCategory.ITEM] = {}
            self.tagToUIDs[LibraryCategory.ABILITY] = {}
            self.tagToUIDs[LibraryCategory.SHAPE] = {}
            self.tagToUIDs[LibraryCategory.FEATURE] = {}
            self.tagToUIDs[LibraryCategory.CREATURE] = {}
        }

        access(Editor)
        fun setSetting(key: LibrarySettings, value: Int64) {
            self.settings[key] = value

            emit LibrarySettingChanged(self.owner?.address ?? panic("Owner not found"), key: key.rawValue, value: value)
        }

        access(Editor)
        fun addObject(object: @Object) {
            pre {
                self.borrowNameToUIDDictionary(LibraryCategory.OBJECT)[object.name] == nil:
                    "Object name already exists"
            }
            let uuid = object.uuid
            let name = object.name
            let tags = object.tags
            self.setNameAndTags(LibraryCategory.OBJECT, uuid, name, tags)

            self.objects[uuid] <-! object

            emit LibraryEntryAdded(
                self.owner?.address ?? panic("Owner not found"),
                LibraryCategory.OBJECT.rawValue,
                uuid,
                name,
                tags
            )
        }

        access(Editor)
        fun addItem(item: @Item) {
            pre {
                self.borrowNameToUIDDictionary(LibraryCategory.ITEM)[item.name] == nil:
                    "Item name already exists"
            }
            let uuid = item.uuid
            let name = item.name
            let tags = item.tags
            self.setNameAndTags(LibraryCategory.ITEM, uuid, name, tags)

            self.items[uuid] <-! item

            emit LibraryEntryAdded(
                self.owner?.address ?? panic("Owner not found"),
                LibraryCategory.ITEM.rawValue,
                uuid,
                name,
                tags
            )
        }

        access(Editor)
        fun addAbility(ability: @Ability) {
            pre {
                self.borrowNameToUIDDictionary(LibraryCategory.ABILITY)[ability.name] == nil:
                    "Ability name already exists"
            }
            let uuid = ability.uuid
            let name = ability.name
            let tags = ability.tags
            self.setNameAndTags(LibraryCategory.ABILITY, uuid, name, tags)

            self.abilities[uuid] <-! ability

            emit LibraryEntryAdded(
                self.owner?.address ?? panic("Owner not found"),
                LibraryCategory.ABILITY.rawValue,
                uuid,
                name,
                tags
            )
        }

        access(Editor)
        fun addShape(shape: @Shape) {
            pre {
                self.borrowNameToUIDDictionary(LibraryCategory.SHAPE)[shape.name] == nil:
                    "Shape name already exists"
            }
            let uuid = shape.uuid
            let name = shape.name
            let tags = shape.tags
            self.setNameAndTags(LibraryCategory.SHAPE, uuid, name, tags)

            self.shapes[uuid] <-! shape

            emit LibraryEntryAdded(
                self.owner?.address ?? panic("Owner not found"),
                LibraryCategory.SHAPE.rawValue,
                uuid,
                name,
                tags
            )
        }

        access(Editor)
        fun addFeature(feature: @Feature) {
            pre {
                self.borrowNameToUIDDictionary(LibraryCategory.FEATURE)[feature.name] == nil:
                    "Feature name already exists"
            }
            let uuid = feature.uuid
            let name = feature.name
            let tags = feature.tags
            self.setNameAndTags(LibraryCategory.FEATURE, uuid, name, tags)

            self.features[uuid] <-! feature

            emit LibraryEntryAdded(
                self.owner?.address ?? panic("Owner not found"),
                LibraryCategory.FEATURE.rawValue,
                uuid,
                name,
                tags
            )
        }

        access(Editor)
        fun addCreature(creature: @Creature) {
            pre {
                self.borrowNameToUIDDictionary(LibraryCategory.CREATURE)[creature.name] == nil:
                    "Creature name already exists"
            }
            let uuid = creature.uuid
            let name = creature.name
            let tags = creature.tags
            self.setNameAndTags(LibraryCategory.CREATURE, uuid, name, tags)

            self.creatures[uuid] <-! creature

            emit LibraryEntryAdded(
                self.owner?.address ?? panic("Owner not found"),
                LibraryCategory.CREATURE.rawValue,
                uuid,
                name,
                tags
            )
        }

        access(Editor)
        fun removeEntry(_ category: LibraryCategory, _ uuid: UInt64) {
            self.removeNameAndTags(category, uuid)

            switch category {
                case LibraryCategory.OBJECT:
                    Burner.burn(<- self.objects.remove(key: uuid))
                case LibraryCategory.ITEM:
                    Burner.burn(<- self.items.remove(key: uuid))
                case LibraryCategory.ABILITY:
                    Burner.burn(<- self.abilities.remove(key: uuid))
                case LibraryCategory.SHAPE:
                    Burner.burn(<- self.shapes.remove(key: uuid))
                case LibraryCategory.FEATURE:
                    Burner.burn(<- self.features.remove(key: uuid))
                case LibraryCategory.CREATURE:
                    Burner.burn(<- self.creatures.remove(key: uuid))
                default:
                    panic("Invalid category")
            }

            emit LibraryEntryRemoved(
                self.owner?.address ?? panic("Owner not found"),
                category.rawValue,
                uuid
            )
        }

        // -------- Public Functions --------

        access(all) view
        fun borrowObject(_ uuid: UInt64): &Object? {
            return &self.objects[uuid]
        }

        access(all) view
        fun borrowObjectByName(_ name: String): &Object? {
            if let uuid = self.borrowNameToUIDDictionary(LibraryCategory.OBJECT)[name] {
                return self.borrowObject(uuid)
            }
            return nil
        }

        access(all) view
        fun borrowItem(_ uuid: UInt64): &Item? {
            return &self.items[uuid]
        }

        access(all) view
        fun borrowItemByName(_ name: String): &Item? {
            if let uuid = self.borrowNameToUIDDictionary(LibraryCategory.ITEM)[name] {
                return self.borrowItem(uuid)
            }
            return nil
        }

        access(all) view
        fun borrowAbility(_ uuid: UInt64): &Ability? {
            return &self.abilities[uuid]
        }

        access(all) view
        fun borrowAbilityByName(_ name: String): &Ability? {
            if let uuid = self.borrowNameToUIDDictionary(LibraryCategory.ABILITY)[name] {
                return self.borrowAbility(uuid)
            }
            return nil
        }

        access(all) view
        fun borrowShape(_ uuid: UInt64): &Shape? {
            return &self.shapes[uuid]
        }

        access(all) view
        fun borrowShapeByName(_ name: String): &Shape? {
            if let uuid = self.borrowNameToUIDDictionary(LibraryCategory.SHAPE)[name] {
                return self.borrowShape(uuid)
            }
            return nil
        }

        access(all) view
        fun borrowFeature(_ uuid: UInt64): &Feature? {
            return &self.features[uuid]
        }

        access(all) view
        fun borrowFeatureByName(_ name: String): &Feature? {
            if let uuid = self.borrowNameToUIDDictionary(LibraryCategory.FEATURE)[name] {
                return self.borrowFeature(uuid)
            }
            return nil
        }

        access(all) view
        fun borrowCreature(_ uuid: UInt64): &Creature? {
            return &self.creatures[uuid]
        }

        access(all) view
        fun borrowCreatureByName(_ name: String): &Creature? {
            if let uuid = self.borrowNameToUIDDictionary(LibraryCategory.CREATURE)[name] {
                return self.borrowCreature(uuid)
            }
            return nil
        }

        access(self) view
        fun borrowNameToUIDDictionary(_ category: LibraryCategory): auth(Mutate) &{String: UInt64} {
            return &self.nameToUID[category] as auth(Mutate) &{String: UInt64}?
                ?? panic("Name to UID dictionary not found")
        }

        access(self) view
        fun borrowTagToUIDsDictionary(_ category: LibraryCategory): auth(Mutate) &{String: [UInt64]} {
            return &self.tagToUIDs[category] as auth(Mutate) &{String: [UInt64]}?
                ?? panic("Tag to UID dictionary not found")
        }

        access(self) view
        fun getTagUIDs(_ category: LibraryCategory, _ tag: String): [UInt64] {
            let tagToUIDs = self.borrowTagToUIDsDictionary(category)
            if let uids = tagToUIDs[tag] {
                return *uids
            }
            return []
        }

        // -------- Private Functions --------

        access(self)
        fun borrowNamable(_ category: LibraryCategory, _ uuid: UInt64): &{Nameable}? {
            switch category {
                case LibraryCategory.OBJECT:
                    return self.borrowObject(uuid)
                case LibraryCategory.ITEM:
                    return self.borrowItem(uuid)
                case LibraryCategory.ABILITY:
                    return self.borrowAbility(uuid)
                case LibraryCategory.SHAPE:
                    return self.borrowShape(uuid)
                case LibraryCategory.FEATURE:
                    return self.borrowFeature(uuid)
                case LibraryCategory.CREATURE:
                    return self.borrowCreature(uuid)
                default:
                    return nil
            }
        }

        access(self)
        fun setNameAndTags(_ category: LibraryCategory, _ uuid: UInt64, _ name: String, _ tags: [String]) {
            let nameToUID = self.borrowNameToUIDDictionary(category)
            let tagToUIDs = self.borrowTagToUIDsDictionary(category)

            // set the name to the uuid
            nameToUID[name] = uuid

            // set the tags to the uuid
            for tag in tags {
                if tagToUIDs[tag] == nil {
                    tagToUIDs[tag] = [uuid]
                } else {
                    tagToUIDs[tag]!.append(uuid)
                }
            }
        }

        access(self)
        fun removeNameAndTags(_ category: LibraryCategory, _ uuid: UInt64) {
            let nameToUID = self.borrowNameToUIDDictionary(category)
            let tagToUIDs = self.borrowTagToUIDsDictionary(category)

            if let namable = self.borrowNamable(category, uuid) {
                let _ = nameToUID.remove(key: namable.name)
                for tag in namable.tags {
                    if let tagArr = tagToUIDs[tag] {
                        if let idIndex = tagArr.firstIndex(of: uuid) {
                            let _ = tagArr.remove(at: idIndex)
                        }
                    }
                }
            }
        }
    }

    // ------------ Library Entities ------------

    access(all) struct interface Copyable {
        access(all) fun copy(): {Copyable}
    }

    access(all) struct Potentiality: Copyable {
        access(all) let initial: Int64
        access(all) var current: Int64
        access(all) var used: Int64

        view init(initial: Int64) {
            self.initial = initial
            self.current = initial
            self.used = 0
        }

        access(all) fun copy(): {Copyable} { return self }

        access(contract)
        fun add(amount: Int64) {
            self.current = self.current + amount
        }

        access(contract)
        fun use(amount: Int64) {
            pre {
                self.current >= amount:
                    "Not enough potentiality"
            }
            self.current = self.current - amount
            self.used = self.used + amount
        }
    }

    // The basic attributes of a character
    access(all) struct Attributes: Copyable {
        access(all) var strength: Int64
        access(all) var vitality: Int64
        access(all) var spirit: Int64

        view init(strength: Int64, vitality: Int64, spirit: Int64) {
            self.strength = strength
            self.vitality = vitality
            self.spirit = spirit
        }

        access(all) fun copy(): {Copyable} { return self }

        access(contract)
        fun setStrength(strength: Int64) {
            self.strength = strength
        }

        access(contract)
        fun addStrength(strength: Int64) {
            self.strength = self.strength + strength
        }

        access(contract)
        fun setVitality(vitality: Int64) {
            self.vitality = vitality
        }

        access(contract)
        fun addVitality(vitality: Int64) {
            self.vitality = self.vitality + vitality
        }

        access(contract)
        fun setSpirit(spirit: Int64) {
            self.spirit = spirit
        }

        access(contract)
        fun addSpirit(spirit: Int64) {
            self.spirit = self.spirit + spirit
        }
    }

    access(all) struct Defence: Copyable {
        access(all) var physical: Int64
        access(all) var endurance: Int64
        access(all) var resistance: Int64

        view init(physical: Int64, endurance: Int64, resistance: Int64) {
            self.physical = physical
            self.endurance = endurance
            self.resistance = resistance
        }

        access(all) fun copy(): {Copyable} { return self }

        access(contract)
        fun setPhysical(physical: Int64) {
            self.physical = physical
        }

        access(contract)
        fun addPhysical(physical: Int64) {
            self.physical = self.physical + physical
        }

        access(contract)
        fun setEndurance(endurance: Int64) {
            self.endurance = endurance
        }

        access(contract)
        fun addEndurance(endurance: Int64) {
            self.endurance = self.endurance + endurance
        }

        access(contract)
        fun setResistance(resistance: Int64) {
            self.resistance = resistance
        }

        access(contract)
        fun addResistance(resistance: Int64) {
            self.resistance = self.resistance + resistance
        }
    }

    access(all) resource interface Nameable {
        access(all) let name: String
        access(all) let tags: [String]

        access(all) view
        fun hasAnyTag(): Bool {
            return self.tags.length > 0
        }

        access(all) view
        fun withTag(_ tag: String): Bool {
            return self.tags.contains(tag)
        }
    }

    // The AttributeCarrier resource interface is used to get the attributes of the entry.
    access(all) resource interface AttributeCarrier {
        access(all) view fun borrowAttributes(): &Attributes?

        access(all) view fun hasAttributes(): Bool {
            return self.borrowAttributes() != nil
        }

        access(all) view fun getAttrStr(): Int64 {
            return self.borrowAttributes()?.strength ?? 0
        }

        access(all) view fun getAttrVit(): Int64 {
            return self.borrowAttributes()?.vitality ?? 0
        }

        access(all) view fun getAttrSpir(): Int64 {
            return self.borrowAttributes()?.spirit ?? 0
        }
    }

    // The DefenceCarrier resource interface is used to get the defence of the entry.
    access(all) resource interface DefenceCarrier {
        access(all) view fun borrowDefence(): &Defence?

        access(all) view fun hasDefence(): Bool {
            return self.borrowDefence() != nil
        }

        access(all) view fun getDefPhys(): Int64 {
            return self.borrowDefence()?.physical ?? 0
        }

        access(all) view fun getDefEnd(): Int64 {
            return self.borrowDefence()?.endurance ?? 0
        }

        access(all) view fun getDefRes(): Int64 {
            return self.borrowDefence()?.resistance ?? 0
        }
    }

    // The PotentialityCarrier resource interface is used to get the potentiality of the entry.
    access(all) resource interface PotentialityCarrier {
        access(all) view fun borrowPotentiality(): &Potentiality?

        access(all) view fun hasPotentiality(): Bool {
            return self.borrowPotentiality() != nil
        }

        access(all) view fun getInitialPotentiality(): Int64 {
            return self.borrowPotentiality()?.initial ?? 0
        }

        access(all) view fun getCurrentPotentiality(): Int64 {
            return self.borrowPotentiality()?.current ?? 0
        }

        access(all) view fun getUsedPotentiality(): Int64 {
            return self.borrowPotentiality()?.used ?? 0
            }
    }

    // The StatusCarrier resource interface is used to get the status of the entry.
    access(all) resource interface OptionalStatusCarrier: AttributeCarrier, DefenceCarrier, PotentialityCarrier {
        // TODO
    }

    access(all) resource interface LiveStatusCarrier: AttributeCarrier, DefenceCarrier, PotentialityCarrier {
        // TODO
        access(all) let attributes: Attributes
        access(all) let defence: Defence
        access(all) let potentiality: Potentiality
    }

    access(all) resource interface ValueCarrier {
        // The value of the item
        access(all) var value: UFix64?

        access(all) view
        fun hasValue(): Bool {
            return self.value != nil
        }

        access(Manage)
        fun setValue(value: UFix64) {
            self.value = value
        }

        access(Manage)
        fun addValue(value: UFix64) {
            self.value = (self.value ?? 0.0) + value
        }
    }

    access(all) resource interface EffectsCarrier {
        access(all) let effects: [String]

        access(all) view
        fun hasEffects(): Bool {
            return self.effects.length > 0
        }

        access(Manage)
        fun addEffect(effect: String) {
            self.effects.append(effect)
        }

        access(Manage)
        fun removeEffect(effect: String) {
            if let index = self.effects.firstIndex(of: effect) {
                let _ = self.effects.remove(at: index)
            }
        }
    }

    access(all) resource Object: DefenceCarrier, ValueCarrier, Nameable {
        access(all) let name: String
        access(all) let tags: [String]
        // The defence of the character
        access(all) let defence: Defence
        // The value of the object
        access(all) var value: UFix64?

        view init(
            name: String,
            tags: [String],
            defence: Defence,
            value: UFix64?
        ) {
            self.name = name
            self.tags = tags
            self.defence = defence
            self.value = value
        }

        access(all) view fun borrowDefence(): &Defence? {
            return &self.defence as &Defence
        }
    }

    access(all) resource Item: OptionalStatusCarrier, ValueCarrier, EffectsCarrier, Nameable {
        access(all) let name: String
        access(all) let tags: [String]
        // The value of the item
        access(all) var value: UFix64?
        // Main attributes of the character
        access(all) let attributes: Attributes
        // The defence of the character
        access(all) let defence: Defence
        // The potentiality of the item
        access(all) let potentiality: Potentiality
        // The effects of the item
        access(all) let effects: [String]
        // The slots occupied by the item
        access(all) let slotsOccupied: {EquipSlot: UInt8}
        // The slots provided by the item
        access(all) let slotsProvided: {EquipSlot: UInt8}

        view init(
            name: String,
            tags: [String],
            value: UFix64?,
            attributes: Attributes,
            defence: Defence,
            effects: [String],
            slotsOccupied: {EquipSlot: UInt8},
            slotsProvided: {EquipSlot: UInt8},
        ) {
            self.name = name
            self.tags = tags
            self.value = value
            self.attributes = attributes
            self.defence = defence
            self.effects = effects
            self.slotsOccupied = slotsOccupied
            self.slotsProvided = slotsProvided
        }
    }

    access(all) resource Ability: AttributeCarrier, EffectsCarrier, Nameable {
        access(all) let name: String
        access(all) let level: UInt64
        access(all) let occupy: Attributes
        access(all) let effects: [String]

        view init(
            level: UInt64,
            name: String,
            occupy: Attributes,
            effects: [String]
        ) {
            self.name = name
            self.level = level
            self.occupy = occupy
            self.effects = effects
        }

        access(all) view fun borrowAttributes(): &Attributes? {
            return &self.occupy as &Attributes
        }
    }

    // The CreatureSettingsCarrier resource interface is used to get the settings of the creature.
    access(all) resource interface CreatureSettingsCarrier {
        access(all) let settings: {CreatureSettings: Int64}

        access(all) view
        fun getSetting(_ setting: CreatureSettings): Int64? {
            return self.settings[setting]
        }

        access(all) view
        fun hasSettings(): Bool {
            return self.settings.length > 0
        }
    }

    access(all) resource Shape: CreatureSettingsCarrier, Nameable {
        access(all) let name: String
        access(all) let settings: {CreatureSettings: Int64}
        access(all) let slotsAvailable: {EquipSlot: UInt8}

        view init(
            name: String,
            bodySize: Int64,
            occupyRange: Int64,
            moveSpeed: Int64,
            perceptionRange: Int64,
            slotsAvailable: {EquipSlot: UInt8 }
        ) {
            self.name = name
            self.settings = {}
            self.slotsAvailable = slotsAvailable

            self.settings[CreatureSettings.SIZE] = bodySize
            self.settings[CreatureSettings.MOVE_SPEED] = moveSpeed
            self.settings[CreatureSettings.PERCEPTION_RANGE] = perceptionRange
            self.settings[CreatureSettings.OCCUPY_RANGE] = occupyRange
        }
    }

    // The ShapeCarrier resource interface is used to get the shape of the creature.
    access(all) resource interface ShapeOverrides: CreatureSettingsCarrier {
        access(all) let settings: {CreatureSettings: Int64}

        access(all) view fun borrowShape(): &Shape?

        access(all) view
        fun getGender(): Int64? {
            if let gender = self.settings[CreatureSettings.GENDER] {
                return gender
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.GENDER)
            }
            return nil
        }

        access(all) view
        fun getForm(): Int64? {
            if let form = self.settings[CreatureSettings.FORM] {
                return form
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.FORM)
            }
            return nil
        }

        access(all) view
        fun getSize(): Int64? {
            if let size = self.settings[CreatureSettings.SIZE] {
                return size
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.SIZE)
            }
            return nil
        }

        access(all) view
        fun getMoveSpeed(): Int64? {
            if let moveSpeed = self.settings[CreatureSettings.MOVE_SPEED] {
                return moveSpeed
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.MOVE_SPEED)
            }
            return nil
        }

        access(all) view
        fun getPerceptionRange(): Int64? {
            if let perceptionRange = self.settings[CreatureSettings.PERCEPTION_RANGE] {
                return perceptionRange
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.PERCEPTION_RANGE)
            }
            return nil
        }

        access(all) view
        fun getOccupyRange(): Int64? {
            if let occupyRange = self.settings[CreatureSettings.OCCUPY_RANGE] {
                return occupyRange
            }
            if let shape = self.borrowShape() {
                return shape.getSetting(CreatureSettings.OCCUPY_RANGE)
            }
            return nil
        }
    }

    // The EntryIdentifier resource is used to identify the entry.
    access(all) struct EntryIdentifier {
        access(all) let library: Address
        access(all) let category: LibraryCategory
        access(all) let id: UInt64

        view init(library: Address, category: LibraryCategory, id: UInt64) {
            pre {
                FGameMishal.borrowLibrary(library) != nil: "It should be a valid library."
            }
            self.library = library
            self.category = category
            self.id = id
        }

        access(all) view
        fun verify(_ type: LibraryCategory): Bool {
            if type != self.category {
                return false
            }
            switch self.category {
                case LibraryCategory.OBJECT:
                    return self.borrowObject() != nil
                case LibraryCategory.ITEM:
                    return self.borrowItem() != nil
                case LibraryCategory.ABILITY:
                    return self.borrowAbility() != nil
                case LibraryCategory.SHAPE:
                    return self.borrowShape() != nil
                case LibraryCategory.FEATURE:
                    return self.borrowFeature() != nil
                case LibraryCategory.CREATURE:
                    return self.borrowCreature() != nil
                default:
                    return false
            }
        }

        access(all) view
        fun borrowObject(): &Object? {
            if self.category == LibraryCategory.OBJECT {
                return self.borrowLibrary().borrowObject(self.id)
            }
            return nil
        }

        access(all) view
        fun borrowItem(): &Item? {
            if self.category == LibraryCategory.ITEM {
                return self.borrowLibrary().borrowItem(self.id)
            }
            return nil
        }

        access(all) view
        fun borrowAbility(): &Ability? {
            if self.category == LibraryCategory.ABILITY {
                return self.borrowLibrary().borrowAbility(self.id)
            }
            return nil
        }

        access(all) view
        fun borrowShape(): &Shape? {
            if self.category == LibraryCategory.SHAPE {
                return self.borrowLibrary().borrowShape(self.id)
            }
            return nil
        }

        access(all) view
        fun borrowFeature(): &Feature? {
            if self.category == LibraryCategory.FEATURE {
                return self.borrowLibrary().borrowFeature(self.id)
            }
            return nil
        }

        access(all) view
        fun borrowCreature(): &Creature? {
            if self.category == LibraryCategory.CREATURE {
                return self.borrowLibrary().borrowCreature(self.id)
            }
            return nil
        }

        access(all) view
        fun borrowLibrary(): &Library {
            return FGameMishal.borrowLibrary(self.library) ?? panic("Library not found")
        }
    }

    access(all) resource interface AbilitiesCarrier {
        access(all) let abilities: [EntryIdentifier]

        access(all)
        fun borrowAbilities(): [&Ability] {
            return self.abilities
                .map(view fun (_ x: EntryIdentifier): &Ability? {
                    return x.borrowAbility()
                })
                .filter(view fun (_ x: &Ability?): Bool {
                    return x != nil
                })
                .map(view fun (_ x: &Ability?): &Ability {
                    return x!
                })
        }

        access(all) view
        fun hasAbilities(): Bool {
            return self.abilities.length > 0
        }
    }

    access(all) resource interface ItemsCarrier {
        access(all) let items: [EntryIdentifier]

        access(all)
        fun borrowItems(): [&Item] {
            return self.items
                .map(view fun (_ x: EntryIdentifier): &Item? {
                    return x.borrowItem()
                })
                .filter(view fun (_ x: &Item?): Bool {
                    return x != nil
                })
                .map(view fun (_ x: &Item?): &Item {
                    return x!
                })
        }

        access(all) view
        fun hasItems(): Bool {
            return self.items.length > 0
        }
    }

    access(all) resource interface ShapeCarrier: ShapeOverrides, Nameable {
        access(all) let name: String
        access(all) let shape: EntryIdentifier?

        access(all) view
        fun borrowShape(): &Shape? {
            if let shape = self.shape {
                return shape.borrowShape()
            }
            return nil
        }

        access(all) view
        fun hasShape(): Bool {
            return self.shape != nil
        }
    }

    // The Feature resource is used to define the features of the entry.
    access(all) resource Feature: Nameable, AbilitiesCarrier, ItemsCarrier, ShapeCarrier, EffectsCarrier {
        access(all) let name: String
        access(all) let attributes: Attributes?
        access(all) let defence: Defence?
        access(all) let potentiality: Potentiality?
        access(all) let effects: [String]
        access(all) let abilities: [EntryIdentifier]
        access(all) let items: [EntryIdentifier]
        access(all) let shape: EntryIdentifier?
        access(all) let settings: {CreatureSettings: Int64}

        view init(
            name: String,
            attributes: Attributes?,
            defence: Defence?,
            potentiality: Potentiality?,
            shape: EntryIdentifier?,
            abilities: [EntryIdentifier],
            items: [EntryIdentifier],
            effects: [String],
            settings: {CreatureSettings: Int64}
        ) {
            self.name = name
            self.attributes = attributes
            self.defence = defence
            self.potentiality = potentiality
            self.shape = shape
            self.abilities = abilities
            self.items = items
            self.effects = effects
            self.settings = settings

            // check identifiers
            if self.shape != nil {
                assert(self.shape!.verify(LibraryCategory.SHAPE), message: "Shape identifier is invalid")
            }
            for abilityIdentifier in abilities {
                assert(abilityIdentifier.verify(LibraryCategory.ABILITY), message: "Ability identifier is invalid")
            }
            for itemIdentifier in items {
                assert(itemIdentifier.verify(LibraryCategory.ITEM), message: "Item identifier is invalid")
            }
        }

        access(all) view
        fun hasAttributes(): Bool {
            return self.attributes != nil
        }

        access(all) view
        fun hasDefence(): Bool {
            return self.defence != nil
        }

        access(all) view
        fun hasPotentiality(): Bool {
            return self.potentiality != nil
        }
    }

    access(all) resource interface FeaturesCarrier {
        access(all) let features: [EntryIdentifier]

        access(all)
        fun borrowFeatures(): [&Feature] {
            return self.features
                .map(view fun (_ x: EntryIdentifier): &Feature? {
                    return x.borrowFeature()
                })
                .filter(view fun (_ x: &Feature?): Bool {
                    return x != nil
                })
                .map(view fun (_ x: &Feature?): &Feature {
                    return x!
                })
        }

        access(all) view
        fun hasFeatures(): Bool {
            return self.features.length > 0
        }
    }

    access(all) resource interface CreatureInterface: LiveStatusCarrier, FeaturesCarrier, AbilitiesCarrier, ItemsCarrier, ShapeOverrides {
        // Main attributes of the character
        access(all) let attributes: Attributes
        // The defence of the character
        access(all) let defence: Defence
        // The potentiality of the character
        access(all) let potentiality: Potentiality
        // The features of the character
        access(all) let features: [EntryIdentifier]
        // The abilities of the character
        access(all) let abilities: [EntryIdentifier]
        // The items of the character
        access(all) let items: [EntryIdentifier]
        // The shape of the character
        access(all) let shape: EntryIdentifier
        // The settings of the character
        access(all) let settings: {CreatureSettings: Int64}

        access(all) view
        fun borrowShape(): &Shape? {
            return self.shape.borrowShape()
        }
    }

    access(all) resource Creature: Nameable, CreatureInterface {
        access(all) let name: String
        // Main attributes of the character
        access(all) let attributes: Attributes
        // The defence of the character
        access(all) let defence: Defence
        // The potentiality of the character
        access(all) let potentiality: Potentiality
        // The features of the character
        access(all) let features: [EntryIdentifier]
        // The abilities of the character
        access(all) let abilities: [EntryIdentifier]
        // The items of the character
        access(all) let items: [EntryIdentifier]
        // The shape of the character
        access(all) let shape: EntryIdentifier
        // The settings of the character
        access(all) let settings: {CreatureSettings: Int64}

        view init(
            name: String,
            attributes: Attributes,
            defence: Defence,
            potentiality: Potentiality,
            features: [EntryIdentifier],
            abilities: [EntryIdentifier],
            items: [EntryIdentifier],
            shape: EntryIdentifier,
            settings: {CreatureSettings: Int64}
        ) {
            self.name = name
            self.attributes = attributes
            self.defence = defence
            self.potentiality = potentiality
            self.features = features
            self.abilities = abilities
            self.items = items
            self.shape = shape
            self.settings = settings


            // check identifiers
            assert(self.shape.verify(LibraryCategory.SHAPE), message: "Shape identifier is invalid")
            for featureIdentifier in features {
                assert(featureIdentifier.verify(LibraryCategory.FEATURE), message: "Feature identifier is invalid")
            }
            for abilityIdentifier in abilities {
                assert(abilityIdentifier.verify(LibraryCategory.ABILITY), message: "Ability identifier is invalid")
            }
            for itemIdentifier in items {
                assert(itemIdentifier.verify(LibraryCategory.ITEM), message: "Item identifier is invalid")
            }
        }
    }

    // ------------ Player ------------

    // The Clonable resource inteface is used to clone the entry.
    access(all) resource interface Clonable {
        access(all) let identifier: EntryIdentifier
        access(Manage) fun clone(): @{Clonable}
    }

    // The Pawn resource is refered to as the character in the game.
    access(all) resource Pawn: CreatureInterface {
        // Main attributes of the character
        access(all) let attributes: Attributes
        // The defence of the character
        access(all) let defence: Defence
        // The potentiality of the character
        access(all) let potentiality: Potentiality
        // The features of the character
        access(all) let features: [EntryIdentifier]
        // The abilities of the character
        access(all) let abilities: [EntryIdentifier]
        // The items of the character
        access(all) let items: [EntryIdentifier]
        // The shape of the character
        access(all) let shape: EntryIdentifier
        // The settings of the character
        access(all) let settings: {CreatureSettings: Int64}

        view init(
            attributes: Attributes,
            defence: Defence,
            potentiality: Potentiality,
            features: [EntryIdentifier],
            abilities: [EntryIdentifier],
            items: [EntryIdentifier],
            shape: EntryIdentifier,
            settings: {CreatureSettings: Int64}
        ) {
            self.attributes = attributes
            self.defence = defence
            self.potentiality = potentiality
            self.features = features
            self.abilities = abilities
            self.items = items
            self.shape = shape
            self.settings = settings


            // check identifiers
            assert(self.shape.verify(LibraryCategory.SHAPE), message: "Shape identifier is invalid")
            for featureIdentifier in features {
                assert(featureIdentifier.verify(LibraryCategory.FEATURE), message: "Feature identifier is invalid")
            }
            for abilityIdentifier in abilities {
                assert(abilityIdentifier.verify(LibraryCategory.ABILITY), message: "Ability identifier is invalid")
            }
            for itemIdentifier in items {
                assert(itemIdentifier.verify(LibraryCategory.ITEM), message: "Item identifier is invalid")
            }
        }
    }

    // ---- Public Functions ----

    access(all)
    fun createLibrary(): @Library {
        return <- create Library()
    }

    access(all) view
    fun borrowLibrary(_ address: Address): &Library? {
        return getAccount(address).capabilities
            .get<&Library>(self.libraryPublicPath)
            .borrow()
    }

    access(all) view
    fun borrowPopularLibrary(): &Library? {
        // Borrow the libraray with the highest item count
        var maxItemCount: UInt64 = 0
        var popularLibrary: &Library? = nil

        let keys = self.libraryItems.keys
        for key in keys {
            if self.libraryItems[key]! > maxItemCount {
                maxItemCount = self.libraryItems[key]!
                if let library = self.borrowLibrary(key) {
                    popularLibrary = library
                }
            }
        }
        return popularLibrary
    }

    init() {
        self.libraryItems = {}

        let identifier = "FGameMishal_".concat(self.account.address.toString())
        self.libraryStoragePath = StoragePath(identifier: identifier.concat("_Library"))!
        self.libraryPublicPath = PublicPath(identifier: identifier.concat("_Library"))!
    }
}
