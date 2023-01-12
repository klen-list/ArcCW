if CLIENT then
    ArcCW.LastWeapon = nil
end

local PLAYER = FindMetaTable("Player")
local isSingleplayer = game.SinglePlayer()

local vec1 = Vector(1, 1, 1)
local vec0 = vec1 * 0
local ang0 = Angle(0, 0, 0)

local lastUBGL = 0

do
    local playerKeyPressed = PLAYER.KeyPressed
    local playerKeyDown = PLAYER.KeyDown
    local playerKeyReleased = PLAYER.KeyReleased
    local playerGetViewModel = PLAYER.GetViewModel

    local sp_cl = isSingleplayer and CLIENT

    local cvarArccwClickToCycle = GetConVar("arccw_clicktocycle")
    local cvarGetBool = FindMetaTable("ConVar").GetBool

    function SWEP:Think()
        local now = CurTime()
        local owner = self:GetOwner()

        local isValidOwner = owner:IsValid()
        if isValidOwner and self:GetClass() == "arccw_base" then
            self:Remove()
            return
        end

        if not isValidOwner or owner:IsNPC() then return end
        local isFirstTimePredicted = IsFirstTimePredicted()

        if self:GetState() == ArcCW.STATE_DISABLE and !self:GetPriorityAnim() then
            self:SetState(ArcCW.STATE_IDLE)
        end

        local state = self:GetState()
        local swepDt = self.dt
    
        for i, v in pairs(self.EventTable) do
            if i ~= 1 and not next(v) then
                self.EventTable[i] = nil
                continue
            end
            for ed, bz in pairs(v) do
                if ed <= now then
                    if bz.AnimKey and (bz.AnimKey != self.LastAnimKey or bz.StartTime != self.LastAnimStartTime) then
                        continue
                    end
                    self:PlayEvent(bz)
                    self.EventTable[i][ed] = nil
                    --print(CurTime(), "Event completed at " .. i, ed)
                end
            end
        end

        if CLIENT and ArcCW.InvHUD and !ArcCW.Inv_Hidden and ArcCW.Inv_Fade == 0 and owner == LocalPlayer() then
            ArcCW.InvHUD:Remove()
            ArcCW.Inv_Fade = 0.01
        end

        local vm = playerGetViewModel(owner)
        self.BurstCount = self:GetBurstCount()

        local sg = swepDt.ShotgunReloading
        if (sg == 2 or sg == 4) and playerKeyPressed(owner, IN_ATTACK) then
            self:SetShotgunReloading(sg + 1)
        elseif (sg >= 2) and swepDt.ReloadingREAL <= now then
            self:ReloadInsert(sg >= 4)
        end

        self:InBipod()

        local downAttack1 = playerKeyDown(owner, IN_ATTACK)
        local downAttack2 = playerKeyDown(owner, IN_ATTACK2)
        
        local currentFiremodeData = self:GetCurrentFiremode()
        local isSecondFiremode = currentFiremodeData.Mode == 2
        local clickToCycleBool = cvarGetBool(cvarArccwClickToCycle)

        if swepDt.NeedCycle and not self.Throwing and !self:GetReloading() 
            and swepDt.WeaponOpDelay < now and self:GetNextPrimaryFire() < now -- Adding this delays bolting if the RPM is too low, but removing it may reintroduce the double pump bug. Increasing the RPM allows you to shoot twice on many multiplayer servers. Sure would be convenient if everything just worked nicely
            and (not clickToCycleBool and (isSecondFiremode or not downAttack1)
            or clickToCycleBool and (isSecondFiremode or playerKeyPressed(owner, IN_ATTACK))) 
        then
            local anim = self:SelectAnimation("cycle")
            anim = self:GetBuff_Hook("Hook_SelectCycleAnimation", anim) or anim
            local mult = self:GetBuff_Mult("Mult_CycleTime")
            local p = self:PlayAnimation(anim, mult, true, 0, true)
            if p then
                self:SetNeedCycle(false)
                self:SetPriorityAnim(now + self:GetAnimKeyTime(anim, true) * mult)
            end
        end

        local serverOrNotSP = not isSingleplayer or SERVER
    
        if swepDt.GrenadePrimed and not (downAttack1 or downAttack2) and serverOrNotSP then
            self:Throw()
        end
    
        if swepDt.GrenadePrimed and self.GrenadePrimeTime > 0 and self.isCooked then
            local heldtime = (now - self.GrenadePrimeTime)
    
            local ft = self:GetBuff_Override("Override_FuseTime") or self.FuseTime
    
            if ft and (heldtime >= ft) and serverOrNotSP then
                self:Throw()
            end
        end
    
        if isFirstTimePredicted and self:GetNextPrimaryFire() < now and playerKeyReleased(owner, IN_USE) then
            if self:InBipod() then
                self:ExitBipod()
            else
                self:EnterBipod()
            end
        end
    
        if not isSingleplayer and self:GetBuff_Override("Override_TriggerDelay", self.TriggerDelay) then
            if playerKeyReleased(owner, IN_ATTACK) and self:GetBuff_Override("Override_TriggerCharge", self.TriggerCharge) and self:GetTriggerDelta(true) >= 1 then
                self:PrimaryAttack()
            else
                self:DoTriggerDelay()
            end
        end
    
        -- maybe it is changed 
        currentFiremodeData = self:GetCurrentFiremode()
        if currentFiremodeData.RunawayBurst then
    
            if self:GetBurstCount() > 0 and not isSingleplayer then
                self:PrimaryAttack()
            end
    
            if self:Clip1() < self:GetBuff("AmmoPerShot") or self:GetBurstCount() == self:GetBurstLength() then
                self:SetBurstCount(0)
                if not currentFiremodeData.AutoBurst then
                    self.Primary.Automatic = false
                end
            end
        end
    
        if playerKeyReleased(owner, IN_ATTACK) then
            local notRunaway = not currentFiremodeData.RunawayBurst
            if notRunaway then
                self:SetBurstCount(0)
                self.LastTriggerTime = -1 -- Cannot fire again until trigger released
                self.LastTriggerDuration = 0
            end
    
            if currentFiremodeData.Mode < 0 and notRunaway then
                local postburst = currentFiremodeData.PostBurstDelay or 0
    
                if (now + postburst) > swepDt.WeaponOpDelay then
                    --self:SetNextPrimaryFire(CurTime() + postburst)
                    self:SetWeaponOpDelay(now + postburst * self:GetBuff_Mult("Mult_PostBurstDelay") + self:GetBuff_Add("Add_PostBurstDelay"))
                end
            end
        end
    
        if owner and owner:GetInfoNum("arccw_automaticreload", 0) == 1 and self:Clip1() == 0 and !self:GetReloading() and now > self:GetNextPrimaryFire() + 0.2 then
            self:Reload()
        end
    
        local isReloading = self:GetReloading()
        local notReloadInSights = not (self:GetBuff_Override("Override_ReloadInSights") or self.ReloadInSights)

        if notReloadInSights and isReloading then
            self:ExitSights()
        end

        local sighted = state == ArcCW.STATE_SIGHTS
    
        if self:GetBuff_Hook("Hook_ShouldNotSight") and (self.Sighted or sighted) then
            self:ExitSights()
        else
    
            -- no it really doesn't, past me
            local toggle = owner:GetInfoNum("arccw_toggleads", 0) >= 1
            local suitzoom = playerKeyDown(owner, IN_ZOOM)
    
            -- if in singleplayer, client realm should be completely ignored
            if toggle and not sp_cl then
                if playerKeyPressed(owner, IN_ATTACK2) then
                    if sighted then
                        self:ExitSights()
                    elseif not suitzoom then
                        self:EnterSights()
                    end
                elseif suitzoom and sighted then
                    self:ExitSights()
                end
            elseif not toggle then
                if (downAttack2 and !suitzoom) and !sighted then
                    self:EnterSights()
                elseif (not downAttack2 or suitzoom) and sighted then
                    self:ExitSights()
                end
            end
    
        end
    
        local spOrFirstTimePredicted = isSingleplayer or isFirstTimePredicted
        if spOrFirstTimePredicted then
            local isInSprint = self:InSprint()
            local state = self:GetState()
            if isInSprint and (state ~= ArcCW.STATE_SPRINT) then
                self:EnterSprint()
            elseif not isInSprint and (state == ArcCW.STATE_SPRINT) then
                self:ExitSprint()
            end
        end

        local frameTime = FrameTime()
    
        if spOrFirstTimePredicted then
            local state = self:GetState()
            self:SetSightDelta(math.Approach(self:GetSightDelta(), state == ArcCW.STATE_SIGHTS and 0 or 1, frameTime / self:GetSightTime()))
            self:SetSprintDelta(math.Approach(self:GetSprintDelta(), state == ArcCW.STATE_SPRINT and 1 or 0, frameTime / self:GetSprintTime()))
        end
    
        if CLIENT and (spOrFirstTimePredicted) then
            self:ProcessRecoil()
        end
    
        if CLIENT and IsValid(vm) then
            self:ThinkVM(vm)
        end
    
        self:DoHeat()
    
        self:ThinkFreeAim()
    
        -- if CLIENT then
            -- if !IsValid(ArcCW.InvHUD) then
            --     gui.EnableScreenClicker(false)
            -- end
    
            -- if self:GetState() != ArcCW.STATE_CUSTOMIZE then
            --     self:CloseCustomizeHUD()
            -- else
            --     self:OpenCustomizeHUD()
            -- end
        -- end
    
        for i, k in ipairs(self.Attachments) do
            if !k.Installed then continue end
            local atttbl = ArcCW.AttachmentTable[k.Installed]
    
            if atttbl.DamagePerSecond then
                local dmg = atttbl.DamagePerSecond * FrameTime()
    
                self:DamageAttachment(i, dmg)
            end
        end
    
        if CLIENT then
            self:DoOurViewPunch()
        end
    
        if self.Throwing and self:Clip1() == 0 and self:Ammo1() > 0 then
            self:SetClip1(1)
            owner:SetAmmo(self:Ammo1() - 1, self.Primary.Ammo)
        end
    
        -- self:RefreshBGs()
    
        if swepDt.MagUpIn != 0 and now > swepDt.MagUpIn then
            self:ReloadTimed()
            self:SetMagUpIn( 0 )
        end
    
        local bottomlessClip = self:HasBottomlessClip()
        local clip1 = self:Clip1() 
        if bottomlessClip and clip1 != ArcCW.BottomlessMagicNumber then
            self:Unload()
            self:SetClip1(ArcCW.BottomlessMagicNumber)
        elseif not bottomlessClip and clip1 == ArcCW.BottomlessMagicNumber then
            self:SetClip1(0)
        end
    
        -- Performing traces in rendering contexts seem to cause flickering with c_hands that have QC attachments(?)
        -- Since we need to run the trace every tick anyways, do it here instead
        if CLIENT then
            self:BarrelHitWall()
        end
    
        self:GetBuff_Hook("Hook_Think")
    
        -- Running this only serverside in SP breaks animation processing and causes CheckpointAnimation to !reset.
        --if SERVER or !isSingleplayer then
            self:ProcessTimers()
        --end
    
        -- Only reset to idle if we don't need cycle. empty idle animation usually doesn't play nice
        if swepDt.NextIdle != 0 and swepDt.NextIdle <= now and !self:GetNeedCycle()
                and self:GetHolster_Time() == 0 and swepDt.ShotgunReloading == 0 then
            self:SetNextIdle(0)
            self:PlayIdleAnimation(true)
        end
    
        if swepDt.UBGLDebounce and not playerKeyDown(owner, IN_RELOAD) then
            self:SetUBGLDebounce( false )
        end
    end
end

local lst = SysTime()

if CLIENT then
    function SWEP:ThinkVM(vm)
        for i = 1, vm:GetBoneCount() do
            vm:ManipulateBoneScale(i, vec1)
        end

        for i, k in pairs(self:GetBuff_Override("Override_CaseBones", self.CaseBones) or {}) do
            if !isnumber(i) then continue end
            for _, b in pairs(istable(k) and k or {k}) do
                local bone = vm:LookupBone(b)

                if !bone then continue end

                if self:GetVisualClip() >= i then
                    vm:ManipulateBoneScale(bone, vec1)
                else
                    vm:ManipulateBoneScale(bone, vec0)
                end
            end
        end

        for i, k in pairs(self:GetBuff_Override("Override_BulletBones", self.BulletBones) or {}) do
            if !isnumber(i) then continue end
            for _, b in pairs(istable(k) and k or {k}) do
                local bone = vm:LookupBone(b)

                if !bone then continue end

                if self:GetVisualBullets() >= i then
                    vm:ManipulateBoneScale(bone, vec1)
                else
                    vm:ManipulateBoneScale(bone, vec0)
                end
            end
        end

        for i, k in pairs(self:GetBuff_Override("Override_StripperClipBones", self.StripperClipBones) or {}) do
            if !isnumber(i) then continue end
            for _, b in pairs(istable(k) and k or {k}) do
                local bone = vm:LookupBone(b)

                if !bone then continue end

                if self:GetVisualLoadAmount() >= i then
                    vm:ManipulateBoneScale(bone, vec1)
                else
                    vm:ManipulateBoneScale(bone, vec0)
                end
            end
        end
    end
end

function SWEP:ProcessRecoil()
    local owner = self:GetOwner()
    local ft = (SysTime() - (lst or SysTime())) * GetConVar("host_timescale"):GetFloat()
    local newang = owner:EyeAngles()
    -- local r = self.RecoilAmount -- self:GetNWFloat("recoil", 0)
    -- local rs = self.RecoilAmountSide -- self:GetNWFloat("recoilside", 0)

    local ra = Angle(ang0)

    ra = ra + (self:GetBuff_Override("Override_RecoilDirection", self.RecoilDirection) * self.RecoilAmount * 0.5)
    ra = ra + (self:GetBuff_Override("Override_RecoilDirectionSide", self.RecoilDirectionSide) * self.RecoilAmountSide * 0.5)

    newang = newang - ra

    local rpb = self.RecoilPunchBack
    local rps = self.RecoilPunchSide
    local rpu = self.RecoilPunchUp

    if rpb != 0 then
        self.RecoilPunchBack = math.Approach(rpb, 0, ft * rpb * 10)
    end

    if rps != 0 then
        self.RecoilPunchSide = math.Approach(rps, 0, ft * rps * 5)
    end

    if rpu != 0 then
        self.RecoilPunchUp = math.Approach(rpu, 0, ft * rpu * 5)
    end

    lst = SysTime()
end

function SWEP:InSprint()
    local owner = self:GetOwner()

    local sm = self.SpeedMult * self:GetBuff_Mult("Mult_SpeedMult") * self:GetBuff_Mult("Mult_MoveSpeed")

    sm = math.Clamp(sm, 0, 1)

    local sprintspeed = owner:GetRunSpeed() * sm
    local walkspeed = owner:GetWalkSpeed() * sm

    local curspeed = owner:GetVelocity():Length()

    if TTT2 and owner.isSprinting == true then
        return (owner.sprintProgress or 0) > 0 and owner:KeyDown(IN_SPEED) and !owner:Crouching() and curspeed > walkspeed and owner:OnGround()
    end

    if !owner:KeyDown(IN_SPEED) or !owner:KeyDown(IN_FORWARD+IN_MOVELEFT+IN_MOVERIGHT+IN_BACK) then return false end
    if !owner:OnGround() then return false end
    if owner:Crouching() then return false end
    if curspeed < Lerp(0.5, walkspeed, sprintspeed) then
        -- provide some grace time so changing directions won't immediately exit sprint
        self.LastExitSprintCheck = self.LastExitSprintCheck or CurTime()
        if self.LastExitSprintCheck < CurTime() - 0.25 then
            return false
        end
    else
        self.LastExitSprintCheck = nil
    end

    return true
end

function SWEP:IsTriggerHeld()
    return self:GetOwner():KeyDown(IN_ATTACK) and (self:CanShootWhileSprint() or (!self.Sprinted or self:GetState() != ArcCW.STATE_SPRINT)) and (self:GetHolster_Time() < CurTime()) and !self:GetPriorityAnim()
end

SWEP.LastTriggerTime = 0
SWEP.LastTriggerDuration = 0
function SWEP:GetTriggerDelta(noheldcheck)
    if self.LastTriggerTime <= 0 or (!noheldcheck and !self:IsTriggerHeld()) then return 0 end
    return math.Clamp((CurTime() - self.LastTriggerTime) / self.LastTriggerDuration, 0, 1)
end

function SWEP:DoTriggerDelay()
    local shouldHold = self:IsTriggerHeld()

    local reserve = self:HasBottomlessClip() and self:Ammo1() or self:Clip1()
    if self.LastTriggerTime == -1 or (!self.TriggerPullWhenEmpty and (reserve < self:GetBuff("AmmoPerShot"))) and self:GetNextPrimaryFire() < CurTime() then
        if !shouldHold then
            self.LastTriggerTime = 0 -- Good to fire again
            self.LastTriggerDuration = 0
        end
        return
    end

    if self:GetBurstCount() > 0 and self:GetCurrentFiremode().Mode == 1 then
        self.LastTriggerTime = -1 -- Cannot fire again until trigger released
        self.LastTriggerDuration = 0
    elseif self:GetNextPrimaryFire() < CurTime() and self.LastTriggerTime > 0 and !shouldHold then
        -- Attack key is released. Stop the animation and clear progress
        local anim = self:SelectAnimation("untrigger")
        if anim then
            self:PlayAnimation(anim, self:GetBuff_Mult("Mult_TriggerDelayTime"), true, 0)
        end
        self.LastTriggerTime = 0
        self.LastTriggerDuration = 0
        self:GetBuff_Hook("Hook_OnTriggerRelease")
    elseif self:GetNextPrimaryFire() < CurTime() and self.LastTriggerTime == 0 and shouldHold then
        -- We haven't played the animation yet. Pull it!
        local anim = self:SelectAnimation("trigger")
        self:PlayAnimation(anim, self:GetBuff_Mult("Mult_TriggerDelayTime"), true, 0, nil, nil, true) -- need to overwrite sprint up
        self.LastTriggerTime = CurTime()
        self.LastTriggerDuration = self:GetAnimKeyTime(anim, true) * self:GetBuff_Mult("Mult_TriggerDelayTime")
        self:GetBuff_Hook("Hook_OnTriggerHeld")
    end
end
