-- We decided to make our own weapon_base because the original one uses `self.Owner` and other bad things
-- However, I do not see the point in putting much effort into optimizing this base, 
-- since most of the functions defined here are overridden within arccw_base
SWEP.PrintName		= "Kent Weapon" -- 'Nice' Weapon name (Shown on HUD)
SWEP.Author			= ""
SWEP.Contact		= ""
SWEP.Purpose		= ""
SWEP.Instructions	= ""

SWEP.ViewModelFOV	= 62
SWEP.ViewModelFlip	= false
SWEP.ViewModel		= "models/weapons/v_pistol.mdl"
SWEP.WorldModel		= "models/weapons/w_357.mdl"

SWEP.Spawnable		= false
SWEP.AdminOnly		= false

SWEP.Primary.ClipSize		= 8			-- Size of a clip
SWEP.Primary.DefaultClip	= 32		-- Default number of bullets in a clip
SWEP.Primary.Automatic		= false		-- Automatic/Semi Auto
SWEP.Primary.Ammo			= "Pistol"

SWEP.Secondary.ClipSize		= 8			-- Size of a clip
SWEP.Secondary.DefaultClip	= 32		-- Default number of bullets in a clip
SWEP.Secondary.Automatic	= false		-- Automatic/Semi Auto
SWEP.Secondary.Ammo			= "Pistol"

--[[---------------------------------------------------------
	Name: SWEP:Initialize()
	Desc: Called when the weapon is first loaded
-----------------------------------------------------------]]
function SWEP:Initialize()
	self:SetHoldType("pistol")
end

--[[---------------------------------------------------------
	Name: SWEP:PrimaryAttack()
	Desc: +attack1 has been pressed
-----------------------------------------------------------]]
do
	local punchAngle = Angle(-1, 0, 0)

	function SWEP:PrimaryAttack()
		-- Make sure we can shoot first
		if (not self:CanPrimaryAttack()) then return end

		-- Play shoot sound
		self:EmitSound("Weapon_AR2.Single")

		-- Shoot 9 bullets, 150 damage, 0.75 aimcone
		self:ShootBullet(150, 1, 0.01, self.Primary.Ammo)

		-- Remove 1 bullet from our clip
		self:TakePrimaryAmmo(1)

		local owner = self:GetOwner()

		-- Punch the player's view
		if (not owner:IsNPC()) then 
			owner:ViewPunch(punchAngle) 
		end
	end
end

--[[---------------------------------------------------------
	Name: SWEP:SecondaryAttack()
	Desc: +attack2 has been pressed
-----------------------------------------------------------]]
do
	local punchAngle = Angle(-10, 0, 0)

	function SWEP:SecondaryAttack()
		-- Make sure we can shoot first
		if (not self:CanSecondaryAttack()) then return end

		-- Play shoot sound
		self:EmitSound("Weapon_Shotgun.Single")

		-- Shoot 9 bullets, 150 damage, 0.75 aimcone
		self:ShootBullet(150, 9, 0.2, self.Secondary.Ammo)

		-- Remove 1 bullet from our clip
		self:TakeSecondaryAmmo(1)

		local owner = self:GetOwner()

		-- Punch the player's view
		if (not owner:IsNPC()) then 
			owner:ViewPunch(punchAngle) 
		end
	end
end

--[[---------------------------------------------------------
	Name: SWEP:Reload()
	Desc: Reload is being pressed
-----------------------------------------------------------]]
function SWEP:Reload()
	self:DefaultReload(ACT_VM_RELOAD)
end

--[[---------------------------------------------------------
	Name: SWEP:Think()
	Desc: Called every frame
-----------------------------------------------------------]]
function SWEP:Think()
end

--[[---------------------------------------------------------
	Name: SWEP:Holster(weapon_to_swap_to)
	Desc: Weapon wants to holster
	RetV: Return true to allow the weapon to holster
-----------------------------------------------------------]]
function SWEP:Holster(wep)
	return true
end

--[[---------------------------------------------------------
	Name: SWEP:Deploy()
	Desc: Whip it out
-----------------------------------------------------------]]
function SWEP:Deploy()
	return true
end

--[[---------------------------------------------------------
	Name: SWEP:ShootEffects()
	Desc: A convenience function to create shoot effects
-----------------------------------------------------------]]
function SWEP:ShootEffects()
	local owner = self:GetOwner()

	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)		-- View model animation
	owner:MuzzleFlash()						-- Crappy muzzle light
	owner:SetAnimation(PLAYER_ATTACK1)		-- 3rd Person Animation
end

--[[---------------------------------------------------------
	Name: SWEP:ShootBullet()
	Desc: A convenience function to shoot bullets
-----------------------------------------------------------]]
do
	local bulletOverride = {
		Num = true,
		Src = true,
		Dir = true,
		Spread = true,
		Tracer = true,
		Force = true,
		Damage = true,
		AmmoType = true
	}

	function SWEP:ShootBullet(damage, num_bullets, aimcone, ammo_type, force, tracer)
		local owner = self:GetOwner()

		bulletOverride.Num		= num_bullets
		bulletOverride.Src		= owner:GetShootPos()			-- Source
		bulletOverride.Dir		= owner:GetAimVector()			-- Dir of bullet
		bulletOverride.Spread	= Vector(aimcone, aimcone, 0)	-- Aim Cone
		bulletOverride.Tracer	= tracer or 5					-- Show a tracer on every x bullets
		bulletOverride.Force	= force or 1					-- Amount of force to give to phys objects
		bulletOverride.Damage	= damage
		bulletOverride.AmmoType = ammo_type or self.Primary.Ammo

		owner:FireBullets(bulletOverride)
		self:ShootEffects()
	end
end

--[[---------------------------------------------------------
	Name: SWEP:TakePrimaryAmmo()
	Desc: A convenience function to remove ammo
-----------------------------------------------------------]]
function SWEP:TakePrimaryAmmo(num)
	local clip1 = self:Clip1()
	-- Doesn't use clips
	if (clip1 <= 0) then
		if (self:Ammo1() <= 0) then return end

		self:GetOwner():RemoveAmmo(num, self:GetPrimaryAmmoType())
	return end

	self:SetClip1(clip1 - num)
end

--[[---------------------------------------------------------
	Name: SWEP:TakeSecondaryAmmo()
	Desc: A convenience function to remove ammo
-----------------------------------------------------------]]
function SWEP:TakeSecondaryAmmo(num)
	local clip2 = self:Clip2()
	-- Doesn't use clips
	if (clip2 <= 0) then
		if (self:Ammo2() <= 0) then return end

		self:GetOwner():RemoveAmmo(num, self:GetSecondaryAmmoType())
	return end

	self:SetClip2(clip2 - num)
end

--[[---------------------------------------------------------
	Name: SWEP:CanPrimaryAttack()
	Desc: Helper function for checking for no ammo
-----------------------------------------------------------]]
function SWEP:CanPrimaryAttack()
	if (self:Clip1() <= 0) then

		self:EmitSound("Weapon_Pistol.Empty")
		self:SetNextPrimaryFire(CurTime() + 0.2)
		self:Reload()
		return false

	end

	return true
end

--[[---------------------------------------------------------
	Name: SWEP:CanSecondaryAttack()
	Desc: Helper function for checking for no ammo
-----------------------------------------------------------]]
function SWEP:CanSecondaryAttack()
	if (self:Clip2() <= 0) then

		self:EmitSound("Weapon_Pistol.Empty")
		self:SetNextSecondaryFire(CurTime() + 0.2)
		return false

	end

	return true
end

--[[---------------------------------------------------------
	Name: OnRemove
	Desc: Called just before entity is deleted
-----------------------------------------------------------]]
function SWEP:OnRemove()
end

--[[---------------------------------------------------------
	Name: OwnerChanged
	Desc: When weapon is dropped or picked up by a new player
-----------------------------------------------------------]]
function SWEP:OwnerChanged()
end

do
	local playerGetAmmoCount = FindMetaTable("Player").GetAmmoCount

	--[[---------------------------------------------------------
		Name: Ammo1
		Desc: Returns how much of ammo1 the player has
		-- !!!
	-----------------------------------------------------------]]
	function SWEP:Ammo1()
		return playerGetAmmoCount(self:GetOwner(), self:GetPrimaryAmmoType())
	end
	
	--[[---------------------------------------------------------
		Name: Ammo2
		Desc: Returns how much of ammo2 the player has
		-- !!!
	-----------------------------------------------------------]]
	function SWEP:Ammo2()
		return playerGetAmmoCount(self:GetOwner(), self:GetSecondaryAmmoType())
	end
end

--[[---------------------------------------------------------
	Name: SetDeploySpeed
	Desc: Sets the weapon deploy speed.
		 This value needs to match on client and server.
-----------------------------------------------------------]]
function SWEP:SetDeploySpeed(speed)
	self.m_WeaponDeploySpeed = tonumber(speed)
end

--[[---------------------------------------------------------
	Name: DoImpactEffect
	Desc: Callback so the weapon can override the impact effects it makes
		 return true to not do the default thing - which is to call UTIL_ImpactTrace in c++
-----------------------------------------------------------]]
function SWEP:DoImpactEffect(tr, nDamageType)
	return false
end
