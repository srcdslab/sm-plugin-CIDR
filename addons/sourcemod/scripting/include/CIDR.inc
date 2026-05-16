#if defined _CIDR_Included
#endinput
#endif
#define _CIDR_Included

/**
 * Called when CIDR ban has been added.
 *
 * @param adminId     	Admin UserId who performed the ban.
 * @param timestamp     Timestamp when action was performed.
 * @param sAction     	The Formated time when the demo started.
 * @noreturn
 */
forward void CIDR_OnActionPerformed(int adminId, int timestamp, char[] sAction);

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
