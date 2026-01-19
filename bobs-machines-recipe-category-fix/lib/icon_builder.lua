--- MIT License
--- See LICENSE.txt for details



--- Class To More Easily Add And Modify Icons
---@class iconBuilder
---@field icons data.IconData[] The icons stored in this builder
local iconBuilder = {}
iconBuilder.__index = iconBuilder

local icon_small_ratio = .333

--- Makes An iconBuilder. Can Pass in an data.IconData[].
---@param icons data.IconData[]|nil
---@return iconBuilder
function iconBuilder.new(icons)
    local icBld = setmetatable({},iconBuilder)
    icBld.icons = {}
    if icons then
        icBld.icons = iconBuilder.normalizeIconData(icons)
    end
    return icBld
end

---Copies `self` and returns a new instance
---@return iconBuilder
function iconBuilder:copy()
    local icons = {}
    for i = 1, #self.icons do -- add original first
        local icon = table.deepcopy(self.icons[i])
        icons[#icons + 1] = icon
    end
    return iconBuilder.new(icons)
end

--- Returns True If There Are No Icons In The iconBuilder
---@return boolean
function iconBuilder:isEmpty()
    return #self.icons == 0
end

---Gets The Prototype's Icon Data And Proccesses It Into An Icon Builder
---@param proto data.Prototype
---@return iconBuilder
function iconBuilder.getIconsFromProto(proto)
    if (not proto.icon) and (not proto.icons) then
        return iconBuilder.new()
    end
    local icons = {}
    if proto.icons == nil then -- For single icon case
        icons = {
            {
                icon = proto.icon,
                icon_size = proto.icon_size,
                icon_mipmaps = proto.icon_mipmaps
            }
        }
    else -- For multiple icons case
        for i = 1, #proto.icons do
            local icon = table.deepcopy(proto.icons[i])
            icons[#icons + 1] = icon
        end
    end
    return iconBuilder.new(icons)
end

--- returns the IconData Representation
---@return data.IconData[]
function iconBuilder:getIcons()
    return self.icons
end
--- returns the IconData Representation
---@return data.IconData[]
function iconBuilder:toIcons()
    return self:getIcons()
end

---Sets The Input Proto's Icon To Be This Icon
---@param proto data.Prototype
---@return null
function iconBuilder:setProtoIcons(proto)
    if self:isEmpty() then
        error('iconBuilder: setProtoIcons: cannot set prototype\'s icons to empty icons')
    end
    proto.icon = nil
    proto.icons = self.icons
    return proto
end

--- Class To Create And Manage Icon Layers
---@class singleIconLayer
---@field icon string Required.  Path to the icon file.
---@field icon_size data.SpriteSizeType The size of the square icon, in pixels. Default: 64
---@field icon_mipmaps integer (Semi-Hidden. I Think number of Mipmaps in the texture)
---@field tint data.Color The tint to apply to the icon.
---@field shift data.Vector Used to offset the icon "layer" from the overall icon.
---@field scale_icon Double Defaults to (expected_icon_size / 2) / icon_size. 
---@field draw_background boolean Default: true for the first layer, false otherwise
---@field floating boolean When true the layer is not considered for calculating bounds of the icon, so it can go out of bounds of rectangle into which the icon is drawn in GUI.
iconBuilder.singleIconLayer = {}
iconBuilder.singleIconLayer.__index = iconBuilder.singleIconLayer
--- Make an icon layer
---@param file_path string
---@param icon_size data.SpriteSizeType defaults to 64 (16bit signed int)
---@param icon_mipmaps integer not required
---@return singleIconLayer
function iconBuilder.makeSingleIconLayer(file_path, icon_size, icon_mipmaps)
    local singleLayer = setmetatable({},iconBuilder.singleIconLayer)
    singleLayer.icon = file_path
    singleLayer.icon_size = icon_size
    singleLayer.icon_mipmaps = icon_mipmaps
    return singleLayer
end

--- Table of red, green, blue, and alpha float values between 0 and 1. Alternatively, values can be from 0-255, they are interpreted as such if at least one value is > 1.
---@param r number float values between 0 and 1. Alternatively, values can be from 0-255
---@param g number float values between 0 and 1. Alternatively, values can be from 0-255
---@param b number float values between 0 and 1. Alternatively, values can be from 0-255
---@param a number float values between 0 and 1. Alternatively, values can be from 0-255
---@return data.Color
function iconBuilder.genColor(r,g,b,a)
    if not a then
        return {r,g,b}
    end
    return {r,g,b,a}
end

--- Converts from the iconBuilder.singleIconLayer class to the data.IconData[] table
---@return data.IconData[]
function iconBuilder.singleIconLayer:toIcons()
    local returns = {}
    for _,val in ipairs({
        'icon',
        'icon_size',
        'icon_mipmaps',
        'tint',
        'shift',
        'scale',
        'draw_background',
        'floating',
    }) do
        if self[val] ~= nil then
            returns[val] = self[val]
        end
    end
    return {returns}
end

--- Converts from the iconBuilder.singleIconLayer class to iconBuilder
---@return iconBuilder
function iconBuilder.singleIconLayer:toIconBuilder()
    return iconBuilder.new(self:toIcons())
end

---Add a tint to the icon layer. Overwrites Previous Tints.
---@param color data.Color
function iconBuilder.singleIconLayer:tint_icon(color)
    if #color > 4 or #color < 3 then
        error('`iconBuilder.singleIconLayer:tint`: color value "'..tostring(color)..'" is of incorrect length. Consider using `iconBuilder.genColor`')
    end
    self.tint = color
    return self
end
--- Shifts the icon by x and y pixels. Adds To Previous Shifts. Typically, Icons Start In The Center.
---@param x number Positive x goes east (Right)
---@param y number Positive y goes south (Down)
function iconBuilder.singleIconLayer:shift_pixels(x, y)
    if not x or not y then
        error('`iconBuilder.singleIconLayer:shift`: x or y is not defined')
    end
    if not self.shift then
        self.shift = {x,y}
        return
    end
    self.shift = {x+self.shift[1], y+self.shift[2]}
    return self
end
--- Scales the icon by scale. Multiplies Previous Scales.
---@param scale number Double.
function iconBuilder.singleIconLayer:scale_icon(scale)
    if not scale then
        error('`iconBuilder.singleIconLayer:scale`: scale is not defined')
    end
    if not self.scale_icon then
        self.scale_icon = scale
        return
    end
    self.scale_icon = self.scale_icon * scale
    return self
end
--- Adds draw_background = true if no value given. First Layer defaults to true
--- @param bool boolean optional
function iconBuilder.singleIconLayer:draw_background_icon(bool)
    if bool == nil then
        self.draw_background = true
        return
    end
    self.draw_background = bool
    return self
end
--- Adds floating = true if no value given.
--- When true the layer is not considered for calculating bounds of the icon, so it can go out of bounds of rectangle into which the icon is drawn in GUI.
--- @param bool boolean optional
function iconBuilder.singleIconLayer:floating_icon(bool)
    if bool == nil then
        self.floating = true
        return
    end
    self.floating = bool
    return self
end

--- Internal Function, Takes Possible IconData Formats and Makes them one format
---@param iconData data.IconData[] | iconBuilder | iconBuilder.singleIconLayer
---@return data.IconData[]
function iconBuilder.normalizeIconData(iconData)
    if iconData['icons'] then
        return iconData.icons
    end
    if iconData['toIcons'] then
        return iconData:toIcons()
    end
    return iconData
end

--- adds inFrontIcons to the front of the iconBuilder icons
---@param inFrontIcons data.IconData[] | iconBuilder | iconBuilder.singleIconLayer
function iconBuilder:addIconsInfront(inFrontIcons)
    local inFrontIcons = iconBuilder.normalizeIconData(inFrontIcons)
    local original = self.icons
    self.icons = {}
    for i = 1, #original do -- add original first
        local icon = table.deepcopy(original[i])
        self.icons[#self.icons + 1] = icon
    end
    for i = 1, #inFrontIcons do -- add inFrontIcons after
        local icon = table.deepcopy(inFrontIcons[i])
        self.icons[#self.icons + 1] = icon
    end
    return self
end
--- adds behindIcons behind the iconBuilder icons
---@param behindIcons data.IconData[] | iconBuilder | iconBuilder.singleIconLayer
function iconBuilder:addIconsbehind(behindIcons)
    local behindIcons = iconBuilder.normalizeIconData(behindIcons)
    local original = self.icons
    self.icons = {}
    for i = 1, #behindIcons do -- add behindIcons first
        local icon = table.deepcopy(behindIcons[i])
        self.icons[#self.icons + 1] = icon
    end
    for i = 1, #original do -- add original after
        local icon = table.deepcopy(original[i])
        self.icons[#self.icons + 1] = icon
    end
    return self
end

--- Internal Function, gets the size (accounting for scale) of an data.IconData instance
---@param singleIcon data.IconData | iconBuilder.singleIconLayer
---@return integer
function iconBuilder.getSingleIconSize(singleIcon)
    if singleIcon.toIcons then
        singleIcon = singleIcon:toIcons()[1]
    end
    local icon_size = 64
    local icon_scale = 1.0
    if singleIcon.icon_size then
        icon_size = singleIcon.icon_size
    end
    if singleIcon.scale then
        icon_scale = singleIcon.scale
    end
    return math.floor(icon_size*icon_scale)
end
--- Internal Function, gets the shift of an data.IconData instance
---@param singleIcon data.IconData | iconBuilder.singleIconLayer
---@return data.Vector Shift A vector is a two-element array or dictionary containing the x and y components. Positive x goes east, positive y goes south.
function iconBuilder.getSingleIconShift(singleIcon)
    if singleIcon.toIcons then
        singleIcon = singleIcon:toIcons()[1]
    end
    local icon_shift = {0,0}
    if singleIcon.shift then
        icon_shift = singleIcon.shift
    end
    return icon_shift
end


--- gets the size of the icon, accounting for icons and shifts
---@return integer icons_size
function iconBuilder:getIconsSize()

    local lft = 0.0 -- Positive x goes right, positive y goes down.
    local rgt = 0.0
    local top = 0.0
    local btm = 0.0

    for i = 1, #self.icons do -- look through each icon
        local icon = self.icons[i]
        if ((not icon.floating) or icon.floating==false) then -- floating icons don`t affect size
            local size = iconBuilder.getSingleIconSize(icon)
            local shift = iconBuilder.getSingleIconShift(icon)
            local size2 = size/2

            local ic_lft = shift[1]-size2 -- icon edges
            local ic_rgt = shift[1]+size2
            local ic_top = shift[2]-size2
            local ic_btm = shift[2]+size2

            lft = (lft < ic_lft) and lft or ic_lft -- update global edges
            rgt = (rgt > ic_rgt) and rgt or ic_rgt
            top = (top < ic_top) and top or ic_top
            btm = (btm > ic_btm) and btm or ic_btm
        end
    end
    -- find final size
    local return_val = math.floor(math.max(rgt-lft,btm-top)) 
    if return_val == 0 then
        return 64
    end
    return return_val
end

--- scales all icons of the `iconBuilder` by the `scaling_factor`
---@param scaling_factor number
function iconBuilder:scaleIcons(scaling_factor)
    local original = self.icons
    self.icons = {}
    for i = 1, #original do -- add original first
        local icon = table.deepcopy(original[i])
        if icon.scale then
            icon.scale = icon.scale * scaling_factor
        else
            icon.scale = scaling_factor
        end
        self.icons[#self.icons + 1] = icon
    end
    return self
end

--- Clears all scaling from the icons
function iconBuilder:resetScale()
    local original = self.icons
    self.icons = {}
    for i = 1, #original do -- add original first
        local icon = table.deepcopy(original[i])
        icon.scale = nil
        self.icons[#self.icons + 1] = icon
    end
    return self
end

--- shifts all icons of the `iconBuilder` by the `shift`. (Shifts Origin Is The Center)
---@param shift data.Vector A vector is a two-element array or dictionary containing the x and y components. Positive x goes east, positive y goes south
---@return iconBuilder
function iconBuilder:shiftIcons(shift)
    local original = self.icons
    self.icons = {}
    for i = 1, #original do -- add original first
        local icon = table.deepcopy(original[i])
        if icon.shift then
            icon.shift = {icon.shift[1]+shift[1],icon.shift[2]+shift[2]}
        else
            icon.shift = shift
        end
        self.icons[#self.icons + 1] = icon
    end
    return self
end
--- Clears all shifts from the icons
function iconBuilder:resetShifts(shift)
    local original = self.icons
    self.icons = {}
    for i = 1, #original do -- add original first
        local icon = table.deepcopy(original[i])
        icon.shift = nil
        self.icons[#self.icons + 1] = icon
    end
    return self
end
--- Scales `scaled_icons` to have a new scale of `relative_scale` compared to `self`
---@param scaled_icons iconBuilder iconBuilder to be rescaled
---@param relative_scale number
---@return iconBuilder scaled_icons
function iconBuilder:formatScaleRelative(scaled_icons, relative_scale)
    local base_size = self:getIconsSize()
    local other_size = scaled_icons:getIconsSize()
    -- base_size * relative_scale = other_size * scaling_factor
    local scaling_factor = (base_size * relative_scale)/other_size
    scaled_icons:scaleIcons(scaling_factor)
    return scaled_icons
end
--- Scales `scaled_icons` to have a new scale to it in the corner of compared to `self`
--- @param scaled_icons iconBuilder iconBuilder to be rescaled
function iconBuilder:formatScaleCorner(scaled_icons)
    return self:formatScaleRelative(scaled_icons,icon_small_ratio)
end

--- Shifts `shifted_icons` relative to the size of `self`. (Shifts Origin Is The Center)
---@param shifted_icons iconBuilder that is being shifted
---@param x number `1.0` means shift icon the size of `1.0*self` east
---@param y number `1.0` means shift icon the size of `1.0*self` south
---@return iconBuilder shifted_icons
function iconBuilder:formatShiftRelative(shifted_icons, x, y)
    local base_size = self:getIconsSize()
    return shifted_icons:shiftIcons({x*base_size,y*base_size})
end

--- Formats `formatted_icons` to exist in the Top Left at a reduced size
---@param formatted_icons iconBuilder
---@param sub_icon_scale float the scale `formatted_icons` icon will be scaled to. Defaults if not given.
---@return iconBuilder formatted_icons
function iconBuilder:formatTopLeft(formatted_icons, sub_icon_scale)
    if formatted_icons == nil then
        error('received a nil value for formatted_icons')
    end
    local new_scale = sub_icon_scale or icon_small_ratio
    local normalized_icons = iconBuilder.new(iconBuilder.normalizeIconData(formatted_icons))
    normalized_icons = self:formatScaleRelative(normalized_icons, new_scale)
    local offset = .25 - ((1.5*new_scale)/4)
    normalized_icons = self:formatShiftRelative(normalized_icons, -offset, -offset)
    return normalized_icons
end
--- Formats `formatted_icons` to exist in the Top Right at a reduced size
---@param formatted_icons iconBuilder
---@param sub_icon_scale float the scale `formatted_icons` icon will be scaled to. Defaults if not given.
---@return iconBuilder formatted_icons
function iconBuilder:formatTopRight(formatted_icons, sub_icon_scale)
    if formatted_icons == nil then
        error('received a nil value for formatted_icons')
    end
    local new_scale = sub_icon_scale or icon_small_ratio
    local normalized_icons = iconBuilder.new(iconBuilder.normalizeIconData(formatted_icons))
    normalized_icons = self:formatScaleRelative(normalized_icons, new_scale)
    local offset = .25 - ((1.5*new_scale)/4)
    normalized_icons = self:formatShiftRelative(normalized_icons, offset, -offset)
    return normalized_icons
end
--- Formats `formatted_icons` to exist in the Top Center at a reduced size
---@param formatted_icons iconBuilder
---@param sub_icon_scale float the scale `formatted_icons` icon will be scaled to. Defaults if not given.
---@return iconBuilder formatted_icons
function iconBuilder:formatTopCenter(formatted_icons, sub_icon_scale)
    if formatted_icons == nil then
        error('received a nil value for formatted_icons')
    end
    local new_scale = sub_icon_scale or icon_small_ratio
    local normalized_icons = iconBuilder.new(iconBuilder.normalizeIconData(formatted_icons))
    normalized_icons = self:formatScaleRelative(normalized_icons, new_scale)
    local offset = .25 - ((1.5*new_scale)/4)
    normalized_icons = self:formatShiftRelative(normalized_icons, 0.0, -offset)
    return normalized_icons
end
--- Formats `formatted_icons` to exist in the Center at a reduced size
---@param formatted_icons iconBuilder
---@param sub_icon_scale float the scale `formatted_icons` icon will be scaled to. Defaults if not given.
---@return iconBuilder formatted_icons
function iconBuilder:formatCenter(formatted_icons, sub_icon_scale)
    if formatted_icons == nil then
        error('received a nil value for formatted_icons')
    end
    local new_scale = sub_icon_scale or icon_small_ratio
    local normalized_icons = iconBuilder.new(iconBuilder.normalizeIconData(formatted_icons))
    normalized_icons = self:formatScaleRelative(normalized_icons, new_scale)
    return normalized_icons
end
--- Formats `formatted_icons` to exist in the Center Left at a reduced size
---@param formatted_icons iconBuilder
---@param sub_icon_scale float the scale `formatted_icons` icon will be scaled to. Defaults if not given.
---@return iconBuilder formatted_icons
function iconBuilder:formatCenterLeft(formatted_icons, sub_icon_scale)
    if formatted_icons == nil then
        error('received a nil value for formatted_icons')
    end
    local new_scale = sub_icon_scale or icon_small_ratio
    local normalized_icons = iconBuilder.new(iconBuilder.normalizeIconData(formatted_icons))
    normalized_icons = self:formatScaleRelative(normalized_icons, new_scale)
    local offset = .25 - ((1.5*new_scale)/4)
    normalized_icons = self:formatShiftRelative(normalized_icons, -offset, 0.0)
    return normalized_icons
end
--- Formats `formatted_icons` to exist in the Center Right at a reduced size
---@param formatted_icons iconBuilder
---@param sub_icon_scale float the scale `formatted_icons` icon will be scaled to. Defaults if not given.
---@return iconBuilder formatted_icons
function iconBuilder:formatCenterRight(formatted_icons, sub_icon_scale)
    if formatted_icons == nil then
        error('received a nil value for formatted_icons')
    end
    local new_scale = sub_icon_scale or icon_small_ratio
    local normalized_icons = iconBuilder.new(iconBuilder.normalizeIconData(formatted_icons))
    normalized_icons = self:formatScaleRelative(normalized_icons, new_scale)
    local offset = .25 - ((1.5*new_scale)/4)
    normalized_icons = self:formatShiftRelative(normalized_icons, offset, 0.0)
    return normalized_icons
end
--- Formats `formatted_icons` to exist in the Bottom Left at a reduced size
---@param formatted_icons iconBuilder
---@param sub_icon_scale float the scale `formatted_icons` icon will be scaled to. Defaults if not given.
---@return iconBuilder formatted_icons
function iconBuilder:formatBottomLeft(formatted_icons, sub_icon_scale)
    if formatted_icons == nil then
        error('received a nil value for formatted_icons')
    end
    local new_scale = sub_icon_scale or icon_small_ratio
    local normalized_icons = iconBuilder.new(iconBuilder.normalizeIconData(formatted_icons))
    normalized_icons = self:formatScaleRelative(normalized_icons, new_scale)
    local offset = .25 - ((1.5*new_scale)/4)
    normalized_icons = self:formatShiftRelative(normalized_icons, -offset, offset)
    return normalized_icons
end
--- Formats `formatted_icons` to exist in the Bottom Right at a reduced size
---@param formatted_icons iconBuilder
---@param sub_icon_scale float the scale `formatted_icons` icon will be scaled to. Defaults if not given.
---@return iconBuilder formatted_icons
function iconBuilder:formatBottomRight(formatted_icons, sub_icon_scale)
    if formatted_icons == nil then
        error('received a nil value for formatted_icons')
    end
    local new_scale = sub_icon_scale or icon_small_ratio
    local normalized_icons = iconBuilder.new(iconBuilder.normalizeIconData(formatted_icons))
    normalized_icons = self:formatScaleRelative(normalized_icons, new_scale)
    local offset = .25 - ((1.5*new_scale)/4)
    normalized_icons = self:formatShiftRelative(normalized_icons, offset, offset)
    return normalized_icons
end
--- Formats `formatted_icons` to exist in the Bottom Center at a reduced size
---@param formatted_icons iconBuilder
---@param sub_icon_scale float the scale `formatted_icons` icon will be scaled to. Defaults if not given.
---@return iconBuilder formatted_icons
function iconBuilder:formatBottomCenter(formatted_icons, sub_icon_scale)
    if formatted_icons == nil then
        error('received a nil value for formatted_icons')
    end
    local new_scale = sub_icon_scale or icon_small_ratio
    local normalized_icons = iconBuilder.new(iconBuilder.normalizeIconData(formatted_icons))
    normalized_icons = self:formatScaleRelative(normalized_icons, new_scale)
    local offset = .25 - ((1.5*new_scale)/4) 
    normalized_icons = self:formatShiftRelative(normalized_icons, 0.0, offset)
    return normalized_icons
end


return iconBuilder
