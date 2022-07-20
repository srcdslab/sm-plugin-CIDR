#if defined _CIDR_Included
	#endinput
#endif
#define _CIDR_Included

forward void CIDR_OnActionPerformed(int client, char[] sAction);

public SharedPlugin __pl_CIDR =
{
	name = "CIDR",
	file = "CIDR.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
