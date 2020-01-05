	


class TestReceiver extends SqRootScript
{
	function OnTestMe()
	{
		ReplyWithObj(0)
		print("I'm " + self + "and I'm doing my stuff NOW")
		Reply(self + ") is Replying!")
	}
}

class TestSendMessage extends SqRootScript
{

	function DGetAllDescendants(at,objset)
	/*Emulation of the "@"-parameter. Gets all descending concrete objects of an archetype or metaproperty.*/
	{
		foreach ( l in Link.GetAll("~MetaProp",at))	//~MetaProp links are invisible in the editor but form the hierarchy of our archetypes. Counterintuitively going from Ancestor to Descendant.
		{
			local id=LinkDest(l)
				if(id>0){objset.append(id)}
				else 	{DGetAllDescendants(id,objset)}
		}
	}

	function OnTest()
	{
	print("=====START SENDING TEST====")
	local objset=[]
	DGetAllDescendants("Marker",objset)
	foreach (obj in objset)
	{
		print("Sending to "+obj)
		print(SendMessage(obj,"TestMe"))
	}
	print("=====END OF SENDING TEST====")
	}

}

class TestPostMessage extends TestSendMessage
{

	function OnTest()
	{
	print("=====START POSTING TEST====")
	local objset=[]
	DGetAllDescendants("Marker",objset)
	foreach (obj in objset)
	{
		print("Sending to "+obj)
		PostMessage(obj,"TestMe")	//no print here as it will be null
	}
	print("=====End of Test====")
	}
}

################################

//Output TestPostMessage:

/*
SQUIRREL> =====START POSTING TEST====
SQUIRREL> Sending to 2
SQUIRREL> Sending to 3
SQUIRREL> Sending to 4
SQUIRREL> =====End of Test====
SQUIRREL> I'm 2and I'm doing my stuff NOW
SQUIRREL> I'm 3and I'm doing my stuff NOW
SQUIRREL> I'm 4and I'm doing my stuff NOW
*/

//Output TestSendMessage

/*
SQUIRREL> =====START SENDING TEST====
SQUIRREL> Sending to 2
SQUIRREL> I'm 2and I'm doing my stuff NOW
SQUIRREL> 2) is Replying!
SQUIRREL> Sending to 3
SQUIRREL> I'm 3and I'm doing my stuff NOW
SQUIRREL> 3) is Replying!
SQUIRREL> Sending to 4
SQUIRREL> I'm 4and I'm doing my stuff NOW
SQUIRREL> 4) is Replying!
SQUIRREL> =====END OF SENDING TEST====
*/