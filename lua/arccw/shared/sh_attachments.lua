function ArcCW:GetAttsForSlot(slot, wep)
    local ret = {}

    for id, _ in pairs(ArcCW.AttachmentTable) do

        if !ArcCW:SlotAcceptsAtt(slot, wep, id) then continue end

        table.insert(ret, id)
    end

    return ret
end

function ArcCW:SlotAcceptsAtt(slot, wep, att)
    local slots = {}

    if isstring(slot) then
        slots[slot] = true
    elseif istable(slot) then
        for _, i in pairs(slot) do
            slots[i] = true
        end
    end

    local atttbl = ArcCW.AttachmentTable[att]

    if atttbl.Hidden then return false end

    if atttbl.NotForNPC and wep.Owner:IsNPC() then
        return false
    end

    if wep.RejectAttachments and wep.RejectAttachments[att] then return false end

    if wep and atttbl.Hook_Compatible then
        local compat = atttbl.Hook_Compatible(wep, {slot = slot, att = att})
        if compat == true then
            return true
        elseif compat == false then
            return false
        end
    end

    if isstring(atttbl.Slot) then
        if !slots[atttbl.Slot] then return false end
    elseif istable(atttbl.Slot) then
        local yeah = false

        for _, i in pairs(atttbl.Slot) do
            if slots[i] then
                yeah = true
                break
            end
        end

        if !yeah then
            return false
        end
    end

    return true
end

function ArcCW:PlayerGetAtts(ply, att)
    if GetConVar("arccw_attinv_free"):GetBool() then return 999 end

    if att == "" then return 999 end

    local atttbl = ArcCW.AttachmentTable[att]

    if atttbl.Free then return 999 end

    if !IsValid(ply) then return 0 end

    if !ply:IsAdmin() then
        if atttbl.AdminOnly then
            return 0
        end
    end

    if atttbl.InvAtt then att = atttbl.InvAtt end

    if !ply.ArcCW_AttInv then return 0 end

    if !ply.ArcCW_AttInv[att] then return 0 end

    return ply.ArcCW_AttInv[att]
end

function ArcCW:PlayerGiveAtt(ply, att, amt)
    amt = amt or 1

    if !IsValid(ply) then return end

    if !ply.ArcCW_AttInv then
        ply.ArcCW_AttInv = {}
    end

    local atttbl = ArcCW.AttachmentTable[att]

    if atttbl.InvAtt then att = atttbl.InvAtt end

    if GetConVar("arccw_attinv_lockmode"):GetBool() then
        if ply.ArcCW_AttInv[att] == 1 then return end
        ply.ArcCW_AttInv[att] = 1
    else
        ply.ArcCW_AttInv[att] = (ply.ArcCW_AttInv[att] or 0) + amt
    end
end

function ArcCW:PlayerTakeAtt(ply, att, amt)
    amt = amt or 1

    if GetConVar("arccw_attinv_lockmode"):GetBool() then return end

    if !IsValid(ply) then return end

    if !ply.ArcCW_AttInv then
        ply.ArcCW_AttInv = {}
    end

    local atttbl = ArcCW.AttachmentTable[att]

    if atttbl.InvAtt then att = atttbl.InvAtt end

    ply.ArcCW_AttInv[att] = ply.ArcCW_AttInv[att] or 0

    if ply.ArcCW_AttInv[att] <= 0 then
        return
    end

    ply.ArcCW_AttInv[att] = (ply.ArcCW_AttInv[att] or 0) - amt

    if ply.ArcCW_AttInv[att] < 0 then
        ply.ArcCW_AttInv[att] = 0
    end
end

if CLIENT then

local function postsetup(wpn)
    if wpn.SetupModel then
        wpn:SetupModel(true)
        if wpn:GetOwner() == LocalPlayer() then
            wpn:SetupModel(false)
        end
    else
        timer.Simple(0.1, function()
            postsetup(wpn)
        end)
    end
end

net.Receive("arccw_networkatts", function(len, ply)
    local wpn = net.ReadEntity()

    if !IsValid(wpn) then return end

    local attnum = net.ReadUInt(8)

    wpn.Attachments = wpn.Attachments or {}

    for i = 1, attnum do
        local attid = net.ReadUInt(ArcCW.GetBitNecessity())

        wpn.Attachments[i] = wpn.Attachments[i] or {}

        if attid == 0 then
            wpn.Attachments[i].Installed = false
            continue
        end

        local att = ArcCW.AttachmentIDTable[attid]

        wpn.Attachments[i].Installed = att

        if wpn.Attachments[i].SlideAmount then
            wpn.Attachments[i].SlidePos = net.ReadFloat()
        end
    end

    wpn.CertainAboutAtts = true

    postsetup(wpn)
end)

net.Receive("arccw_sendattinv", function(len, ply)
    LocalPlayer().ArcCW_AttInv = {}

    local count = net.ReadUInt(32)

    for i = 1, count do
        local attid = net.ReadUInt(ArcCW.GetBitNecessity())
        local acount = net.ReadUInt(32)

        local att = ArcCW.AttachmentIDTable[attid]

        LocalPlayer().ArcCW_AttInv[att] = acount
    end
end)

elseif SERVER then

hook.Add("PlayerSpawn", "ArcCW_SpawnAttInv", function(ply, trans)
    if trans then return end

    if GetConVar("arccw_attinv_loseondie"):GetBool() then
        ply.ArcCW_AttInv = {}

        ArcCW:PlayerSendAttInv(ply)
    end
end)

net.Receive("arccw_rqwpnnet", function(len, ply)
    local wpn = net.ReadEntity()

    if !wpn.ArcCW then return end

    wpn:NetworkWeapon(ply)
end)

net.Receive("arccw_slidepos", function(len, ply)
    local wpn = ply:GetActiveWeapon()

    local slot = net.ReadUInt(8)
    local pos = net.ReadFloat()

    if !wpn.ArcCW then return end

    if !wpn.Attachments[slot] then return end

    wpn.Attachments[slot].SlidePos = pos
end)

net.Receive("arccw_asktoattach", function(len, ply)
    local wpn = ply:GetActiveWeapon()

    local slot = net.ReadUInt(8)
    local attid = net.ReadUInt(24)

    local att = ArcCW.AttachmentIDTable[attid]

    if !wpn.ArcCW then return end
    if !wpn.Attachments[slot] then return end
    if !att then return end

    wpn:Attach(slot, att)
end)

net.Receive("arccw_asktodetach", function(len, ply)
    local wpn = ply:GetActiveWeapon()

    local slot = net.ReadUInt(8)

    if !wpn.ArcCW then return end
    if !wpn.Attachments[slot] then return end

    wpn:Detach(slot)
end)

net.Receive("arccw_asktodrop", function(len, ply)

    local attid = net.ReadUInt(24)
    local att = ArcCW.AttachmentIDTable[attid]

    if GetConVar("arccw_attinv_free"):GetBool() then return end
    if GetConVar("arccw_attinv_lockmode"):GetBool() then return end
    if !att then return end
    if ArcCW.AttachmentTable[att].Free then return end
    if ArcCW:PlayerGetAtts(ply, att) < 1 then return end

    local ent = ents.Create("acwatt_" .. att)
    if !IsValid(ent) then return end
    ent:SetPos(ply:EyePos() + ply:EyeAngles():Forward() * 32)
    ent:Spawn()
    timer.Simple(0, function()
        local phys = ent:GetPhysicsObject()
        if phys:IsValid() then
            phys:SetVelocity(ply:EyeAngles():Forward() * 32 * math.max(phys:GetMass(), 4))
        end
    end)
    ArcCW:PlayerTakeAtt(ply, att, 1)
    ArcCW:PlayerSendAttInv(ply)
    ply:ViewPunch(Angle(-0.5, 0, 0))
end)

function ArcCW:PlayerSendAttInv(ply)
    if GetConVar("arccw_attinv_free"):GetBool() then return end

    if !IsValid(ply) then return end

    if !ply.ArcCW_AttInv then return end

    net.Start("arccw_sendattinv")

    net.WriteUInt(table.Count(ply.ArcCW_AttInv), 32)

    for att, count in pairs(ply.ArcCW_AttInv) do
        local atttbl = ArcCW.AttachmentTable[att]
        local attid = atttbl.ID
        net.WriteUInt(attid, ArcCW.GetBitNecessity())
        net.WriteUInt(count, 32)
    end

    net.Send(ply)
end

end