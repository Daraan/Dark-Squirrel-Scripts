##### How Reply works #####

// Roughly spoken this is the return value of an ObjB.OnMessage() to an ObjA.SendMessage(ObjB,"Message").

// More detailed explanation:
//	When using SendMessage the current function A gets suspended.
//  If there is a message handler function B on the send to object, function B will be executed first before the initial function A continues.
//	There in the function B you can use Reply(valuefromB)
//	This valuefromB will then be returned to function A at the position of SendMessage(ObjB,...)
////
//// NOTE: When multiple scripts >on the same object< react to the same message with Reply only one, the last one called, is returned.
// Reply is often used by OnPhysMessage to return results to the engine.

## Post Message is Per Frame ##
//
// Another probably not known difference. Post Messages will be sent per frame. SendMessage can be sent multiple times per frame
//
//	This will run without problems:
//	function OnMessage()
//		PostMessage(self, test)
//	
//	This will cause a stack overflow:
//	function OnMessage()
//		SendMessage(self,test)
//

#### Outuputs of the following functions:
// Both Test functions are nearly identical. Only PostMessage(...) has been replaced with print(SendMessage(...))

// Output TestPostMessage:

/*
SQUIRREL> =====START POSTING TEST====
SQUIRREL> Sending to 2
SQUIRREL> Sending to 3
SQUIRREL> Sending to 4
SQUIRREL> =====End of Test====
SQUIRREL> I'm 2and I'm doing my stuff NOW
SQUIRREL> I'm 3and I'm doing my stuff NOW
SQUIRREL> I'm 4and I'm doing my stuff NOW
	// There will be no replies.
*/

//Output TestSendMessage

/*
SQUIRREL> =====START SENDING TEST====
SQUIRREL> Sending to 2
SQUIRREL> I'm 2and I'm doing my stuff NOW
SQUIRREL> 2) is Replying!
//----------------------------
SQUIRREL> Sending to 3
SQUIRREL> I'm 3and I'm doing my stuff NOW
SQUIRREL> 3) is Replying!
//----------------------------
SQUIRREL> Sending to 4
SQUIRREL> I'm 4and I'm doing my stuff NOW
SQUIRREL> 4) is Replying!
//----------------------------
SQUIRREL> =====END OF SENDING TEST====
*/


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

	function OnTest(){
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
	function OnTest(){
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

