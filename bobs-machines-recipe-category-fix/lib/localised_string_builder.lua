--- MIT License
--- See LICENSE.txt for details

--- Class To More Easily Create Localised Strings
---@class localisedStringBuilder
---@field locale data.LocalisedString
local localisedStringBuilder = {}
localisedStringBuilder.__index = localisedStringBuilder

--- Makes An localisedStringBuilder. Can Pass in data.LocalisedString
---@param locale data.LocalisedString
---@return localisedStringBuilder
function localisedStringBuilder.new(locale)
    local lsBld = setmetatable({},localisedStringBuilder)
    lsBld.locale = {}
    if locale then
        lsBld.locale = localisedStringBuilder.normalizeData(locale)
    end
    return lsBld
end

--- Creates a localisedStringBuilder from a template key (and optional parameters)
---@param key string the key that maps a locale file template
---@param ... data.LocalisedString parameters to the key
---@return localisedStringBuilder
function localisedStringBuilder.createLocale(key, ...)
    local vals = {key}
    local params = {...}
    if params then
        for _, value in ipairs(params) do
            vals[#vals+1] = value
        end
    end
    return localisedStringBuilder.new(vals)
end

---Internal Function, Takes Possible LocalisedString Formats and Makes them one format
---@param data localisedStringBuilder|data.LocalisedString
---@return data.LocalisedString
function localisedStringBuilder.normalizeData(data)
    if type(data) == 'string' then
        return {data}
    end
    if data['locale'] then
        return data.locale
    end
    return data
end

---Copies `self` and returns a new instance
---@return localisedStringBuilder
function localisedStringBuilder:copy()
    local locale = {}
    for i = 1, #self.locale do -- add original first
        local ls = table.deepcopy(self.locale[i])
        locale[#locale + 1] = ls
    end
    return localisedStringBuilder.new(locale)
end

--- returns the LocalisedString Representation
---@return data.LocalisedString[]
function localisedStringBuilder:toLocalisedString()
    return self.locale
end


--- Appends `data` to the end of the LocalisedString
---@param data data.LocalisedString|string
---@return localisedStringBuilder
function localisedStringBuilder:add(data)
    data = localisedStringBuilder.normalizeData(data)
    if (not (self.locale[0])) or self.locale[0] ~= '' then
        self.locale = {'',self.locale}
    end
    self.locale[#self.locale+1] = data
    return self
end

--- Adds a fallback string that's used if the original fails
---@param fallback data.LocalisedString|string
---@return localisedStringBuilder
function localisedStringBuilder:addFallback(fallback)
    fallback = localisedStringBuilder.normalizeData(fallback)
    self.locale = {'?',self.locale,fallback}
    return self
end


return localisedStringBuilder
