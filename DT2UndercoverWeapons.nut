#############Undercover scripts##########
//T2 ONLY! For DScript Version v0.24+

//IF you're not using DImUndercover I would suggest you comment everything out or delete this file.
//As I'm REPLACING THE STANDARD WEAPON SCRIPTS scrips to make them suspicious
##Real propblem is actually the bow, while sword and blackjack can be made suspicious just by addin the property (that's all the melee scripts do here) the bow needs special handling.

if (GetDarkGame() == 2)
{

class Arrow extends SqRootScript
{
// METHODS:

	function UnEquipMe()
	{
		Property.Set("Player","SuspObj","Suspicious Type",GetData("Selected"))	//Added
		Bow.UnEquip();
		DrkInv.RemoveSpeedControl("BowDraw");
	}

// MESSAGES:

	function OnBeginScript()
	{
		if ( !IsDataSet("Selected") )
			SetData("Selected", FALSE);
	}

	function OnFrobInvBegin()
	{
		if (message().Abort)
		{
			Bow.AbortAttack();
			DrkInv.RemoveSpeedControl("BowDraw");
		}
		else
		{
			Link.DestroyMany("~AISuspiciousLink","Player","@Creature") //Added
			Property.Set("Player","SuspObj","Suspicious Type","blood") //Instant alert if seen.
			Bow.StartAttack();
			DrkInv.AddSpeedControl("BowDraw", 0.75, 1.0);
		}
	}

	function OnFrobInvEnd()
	{
		local retval = Bow.FinishAttack();
		DrkInv.RemoveSpeedControl("BowDraw");
		Property.Set("Player","SuspObj","Suspicious Type",GetData("Selected")) //Added
		Reply(retval);
	}

	function OnInvSelect()
	{
		SetData("Selected", Property.Get("Player", "SuspObj","Suspicious Type"))//Changed to save the type.
		Bow.SetArrow(self);
		Bow.Equip();
	}

	function OnInvDeSelect()
	{
		UnEquipMe();
		SetData("Selected", FALSE);
	}

	function OnDestroy()
	{
		if ( GetData("Selected") )
			UnEquipMe();
	}
}

//These can be deleted if the suspicious stuff is set ingame.

class BlackJack extends SqRootScript
{
// MESSAGES:

	function OnFrobInvBegin()
	{
		if (message().Abort)
			Weapon.FinishAttack(message().Frobber, message().SrcObjId);
		else
			Weapon.StartAttack(message().Frobber, message().SrcObjId);
	}

	function OnFrobInvEnd()
	{
		Weapon.FinishAttack(message().Frobber, message().SrcObjId);
	}

	function OnFrobToolBegin()
	{
		Weapon.StartAttack(message().Frobber, message().SrcObjId);
	}

	function OnFrobToolEnd()
	{
		Weapon.FinishAttack(message().Frobber, message().SrcObjId);
	}

	function OnInvSelect()	//Added; this could also be put in a constructor but then would work on decorative swords as well
	{
		Property.Add(self,"SuspObj")					
		Property.Set(self,"SuspObj","Is Suspicious",true)
		Property.Set(self,"SuspObj","Suspicious Type","blood")
		Weapon.Equip(self, eDarkWeaponType.kDWT_BlackJack);
	}

	function OnInvDeSelect()
	{
		Weapon.UnEquip(self);
	}
}

class Sword extends SqRootScript
{
// MESSAGES:
	
	
	function OnFrobInvBegin()
	{
		if (message().Abort)
			Weapon.FinishAttack(message().Frobber, message().SrcObjId);
		else
			Weapon.StartAttack(message().Frobber, message().SrcObjId);
	}

	function OnFrobInvEnd()
	{
		Weapon.FinishAttack(message().Frobber, message().SrcObjId);
	}

	function OnFrobToolBegin()
	{
		Weapon.StartAttack(message().Frobber, message().SrcObjId);
	}

	function OnFrobToolEnd()
	{
		Weapon.FinishAttack(message().Frobber, message().SrcObjId);
	}

	function OnInvSelect() //Added; this could also be put in a constructor but then would work on decorative swords as well
	{
		Property.Add(self,"SuspObj")
		Property.Set(self,"SuspObj","Is Suspicious",true)
		Property.Set(self,"SuspObj","Suspicious Type","blood")
		Weapon.Equip(self, eDarkWeaponType.kDWT_Sword);
		DrkInv.AddSpeedControl("SwordEquip", 0.75, 0.8);
	}

	function OnInvDeSelect()
	{
		Weapon.UnEquip(self);
		DrkInv.RemoveSpeedControl("SwordEquip");
	}
}

}
