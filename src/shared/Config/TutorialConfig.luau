--!strict
export type TutorialReward = {
	cash: number?,
	gems: number?,
	crateId: string?,
	crateCount: number?,
	title: string?,
}

export type TutorialStepDef = {
	stepNumber: number,
	id: string,
	title: string,
	description: string,
	shortInstruction: string,
	actionType: "MINE_ORE" | "OPEN_CRATE" | "BUY_PICKAXE" | "EQUIP_PET",
	targetCount: number,
	targetUI: string?, -- Button name in UIController SideMenu e.g. "CratesBtn", "ShopBtn", "PetsBtn"
	worldTarget: string?, -- "NEAREST_ORE" | "BLACKSMITH" | "HATCHERY"
	reward: TutorialReward,
	rewardText: string,
	icon: string,
}

local TutorialConfig = {}

TutorialConfig.TOTAL_STEPS = 5

TutorialConfig.STEPS = {
	[1] = {
		stepNumber = 1,
		id = "mine_first_ore",
		title = "First Strike",
		description = "Swing your pickaxe and shatter your first ore in Zone 1!",
		shortInstruction = "Mine 1 ore nearby",
		actionType = "MINE_ORE",
		targetCount = 1,
		targetUI = nil,
		worldTarget = "NEAREST_ORE",
		reward = {
			cash = 500,
			gems = 50,
		},
		rewardText = "+$500 Cash • +50 💎",
		icon = "⛏️",
	},
	[2] = {
		stepNumber = 2,
		id = "collect_ores",
		title = "Resource Gathering",
		description = "Mine 3 more ores to build up your cash and earn a mystery crate!",
		shortInstruction = "Mine 3 more ores",
		actionType = "MINE_ORE",
		targetCount = 3,
		targetUI = nil,
		worldTarget = "NEAREST_ORE",
		reward = {
			cash = 1500,
			crateId = "box_wooden",
			crateCount = 1,
		},
		rewardText = "+$1,500 Cash • 📦 1x Wooden Crate",
		icon = "💎",
	},
	[3] = {
		stepNumber = 3,
		id = "open_crate",
		title = "Mystery Unboxing",
		description = "Open your new Wooden Crate from the Crates menu to discover rare loot!",
		shortInstruction = "Open 1 Mystery Crate",
		actionType = "OPEN_CRATE",
		targetCount = 1,
		targetUI = "CratesBtn",
		worldTarget = nil,
		reward = {
			cash = 1000,
			gems = 100,
		},
		rewardText = "+$1,000 Cash • +100 💎",
		icon = "📦",
	},
	[4] = {
		stepNumber = 4,
		id = "upgrade_pickaxe",
		title = "Blacksmith Upgrade",
		description = "Visit the Shop and upgrade to a stronger pickaxe for huge mining boosts!",
		shortInstruction = "Buy a new Pickaxe in Shop",
		actionType = "BUY_PICKAXE",
		targetCount = 1,
		targetUI = "ShopBtn",
		worldTarget = "BLACKSMITH",
		reward = {
			cash = 2500,
			gems = 150,
		},
		rewardText = "+$2,500 Cash • +150 💎",
		icon = "🛒",
	},
	[5] = {
		stepNumber = 5,
		id = "equip_pet",
		title = "Loyal Companion",
		description = "Hatch an egg or equip a pet to gain permanent coin and gem multipliers!",
		shortInstruction = "Hatch or Equip a Pet",
		actionType = "EQUIP_PET",
		targetCount = 1,
		targetUI = "PetsBtn",
		worldTarget = "HATCHERY",
		reward = {
			cash = 10000,
			gems = 500,
			title = "Novice Miner",
		},
		rewardText = "🎓 +$10,000 Cash • +500 💎 • Novice Title",
		icon = "🐾",
	},
} :: { [number]: TutorialStepDef }

function TutorialConfig.getStep(stepNum: number): TutorialStepDef?
	return TutorialConfig.STEPS[stepNum]
end

function TutorialConfig.getTotalSteps(): number
	return TutorialConfig.TOTAL_STEPS
end

return TutorialConfig
