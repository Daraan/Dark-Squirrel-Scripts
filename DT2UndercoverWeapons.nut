#############Undercover scripts##########
/*T2 ONLY! For DScript Version v0.24+ and the DImUndercoverScript

IF you ARE NOT using DImUndercover better DELETE this file. INCLUDE it in your map if you do.
It replaces the standard weapons scripts. Weapons will not behave diffrently though but I would recommend let the game use the standard ones.

NOTE:The real propblem is actually the bow, while sword and blackjack can be made suspicious just by adding the property (that's all the melee scripts here do) 
the bow needs special handling.
There might be a work arround making the arm object suspicious. TODO: Think about it.
##########################################*/

if (GetDarkGame() == 2)
{

//These melee scripts can be deleted if the suspicious stuff is set in the editor on the objects itself or via NVNewWeapon+Metaproperty.

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

	function OnInvSelect()	//Added; this could also be put in a constructor but then would work on decorative swords as well. TODO Only works if contained.
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



class Arrow extends SqRootScript
{
// METHODS:

	function UnEquipMe()
	{
		Property.Set("Player","SuspObj","Suspicious Type",GetData("Selected"))	//If you used a custom SuspType for the player it want to restore it.
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
			Link.DestroyMany("~AISuspiciousLink","Player","@Creature") //New line. TODO: Read what Susp Links do again.
			Property.Set("Player","SuspObj","Suspicious Type","blood") //New line, will instantly alert if seen.
			Bow.StartAttack();
			DrkInv.AddSpeedControl("BowDraw", 0.75, 1.0);
		}
	}

	function OnFrobInvEnd()
	{
		local retval = Bow.FinishAttack();
		DrkInv.RemoveSpeedControl("BowDraw");
		Property.Set("Player","SuspObj","Suspicious Type",GetData("Selected")) //Restore the intial type.
		Reply(retval);
	}

	function OnInvSelect()
	{
		SetData("Selected", Property.Get("Player", "SuspObj","Suspicious Type"))//Store the initial set SuspType on the player.
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
	
}
