--!strict
local FormatNumber = {}

local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"
}

function FormatNumber.formatCompact(value: number?): string
	if not value then return "0" end
	if value < 1000 then
		return string.format("%d", math.floor(value))
	end

	local exp = math.min(math.floor(math.log(value, 10) / 3), #SUFFIXES - 1)
	local scaled = value / (10 ^ (exp * 3))

	if scaled >= 100 then
		return string.format("%.0f%s", scaled, SUFFIXES[exp + 1])
	elseif scaled >= 10 then
		return string.format("%.1f%s", scaled, SUFFIXES[exp + 1])
	else
		return string.format("%.2f%s", scaled, SUFFIXES[exp + 1])
	end
end

function FormatNumber.formatComma(value: number?): string
	if not value then return "0" end
	local formatted = tostring(math.floor(value))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

function FormatNumber.format(value: number?): string
	return FormatNumber.formatComma(value)
end

return FormatNumber
