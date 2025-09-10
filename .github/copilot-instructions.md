# Copilot Instructions for CIDR Block Plugin

## Repository Overview

This repository contains a **CIDR Block plugin** for SourceMod, a scripting platform for Source engine games. The plugin provides IP address blocking functionality using CIDR notation, allowing administrators to ban individual IPs, IP ranges, or entire subnets from game servers.

**Core Functionality:**
- Block IP addresses using CIDR notation (e.g., 192.168.1.0/24)
- Administrative commands for adding and managing bans
- Temporary and permanent ban support  
- File-based ban storage with automatic loading
- Forward events for third-party plugin integration

## Technical Environment

- **Language**: SourcePawn (.sp files)
- **Platform**: SourceMod 1.12+ (compatible with 1.11.0-git6934+)
- **Build System**: SourceKnight (configured via `sourceknight.yaml`)
- **Dependencies**: MultiColors library for chat formatting
- **Compiler**: SourcePawn Compiler (spcomp) via SourceKnight

## Project Structure

```
addons/sourcemod/
├── scripting/
│   ├── CIDR.sp              # Main plugin source code
│   └── include/
│       └── CIDR.inc         # API include file for other plugins
├── plugins/                 # Compiled .smx files (build output)
├── configs/                 # Configuration files (cidrblock.cfg)
└── translations/            # Language files (none currently)
```

**Key Files:**
- `sourceknight.yaml` - Build configuration and dependencies
- `CIDR.sp` - Main plugin implementation
- `CIDR.inc` - Public API for plugin integration
- `.github/workflows/ci.yml` - CI/CD pipeline

## Build System (SourceKnight)

This project uses **SourceKnight** for building and dependency management:

```bash
# Install SourceKnight (if not available)
pip install sourceknight

# Build the plugin
sourceknight build

# Build output location
.sourceknight/package/addons/sourcemod/plugins/CIDR.smx
```

**Dependencies** (managed via sourceknight.yaml):
- SourceMod 1.11.0-git6934 (base platform)
- MultiColors library (chat formatting)

## Code Style & Standards

### SourcePawn Conventions
```sourcepawn
// Required pragmas at file start
#pragma semicolon 1
#pragma newdecls required

// Variable naming
bool g_bVariableName;           // Global variables: g_ prefix + Hungarian notation
int g_iClientData[MAXPLAYERS];  // Arrays and special types
Handle g_hConVar;               // Handles (legacy - prefer methodmaps)

// Function naming  
public void OnPluginStart()     // Public functions: PascalCase
stock bool IsValidClient()      // Stock functions: PascalCase
void LoadConfiguration()        // Private functions: PascalCase

// Local variables and parameters
int clientId, targetIndex;      // camelCase for locals and parameters
```

### Modern SourcePawn Practices (CRITICAL)

**Memory Management:**
```sourcepawn
// ❌ WRONG - Memory leaks
Handle hArray = CreateArray();
ClearArray(hArray);  // Creates memory leak!
CloseHandle(hArray); // Old syntax

// ✅ CORRECT - Proper cleanup
ArrayList aList = new ArrayList();
delete aList;  // Automatically handles cleanup
aList = new ArrayList();  // Recreate if needed
```

**Handle Usage:**
```sourcepawn
// ❌ WRONG - Old Handle syntax
Handle hFile = OpenFile(path, "r");
CloseHandle(hFile);

// ✅ CORRECT - Use delete for cleanup
File hFile = OpenFile(path, "r");
delete hFile;  // No null check needed
```

**ConVar Usage:**
```sourcepawn
// ✅ MODERN - Use ConVar methodmap
ConVar g_cvPath = CreateConVar("sm_cidr_path", "configs/cidrblock.cfg");
char buffer[256];
g_cvPath.GetString(buffer, sizeof(buffer));
```

## Plugin-Specific Patterns

### CIDR Processing
```sourcepawn
// IP to integer conversion for range checking
int inet_aton(const char[] ip)
{
    char pieces[4][16];
    int nums[4];
    ExplodeString(ip, ".", pieces, 4, 16);
    nums[0] = StringToInt(pieces[0]); // Continue for all 4 octets
    return ((nums[0] << 24) | (nums[1] << 16) | (nums[2] << 8) | nums[3]);
}

// CIDR range calculation
int shift = 32 - prefix;
int mask = (1 << shift) - 1;
int start = baseip >> shift << shift;
int end = start | mask;
```

### File Operations
```sourcepawn
// Always use BuildPath for SourceMod paths
char path[PLATFORM_MAX_PATH];
BuildPath(Path_SM, path, sizeof(path), "configs/cidrblock.cfg");

// Proper file handling
File hFile = OpenFile(path, "a+r");
if (hFile == null) {
    LogError("Failed to open file: %s", path);
    return;
}
// Process file...
delete hFile;
```

### Client Validation
```sourcepawn
// Standard client validation function
stock bool IsValidClient(int client, bool nobots = true)
{
    if (client <= 0 || client > MaxClients || !IsClientConnected(client))
        return false;
    if (nobots && IsFakeClient(client))
        return false;
    return IsClientInGame(client);
}
```

## Common Issues to Avoid

### Memory Leaks
- **Never** use `ClearArray()` - use `delete` and recreate
- Always use `delete` instead of `CloseHandle()`
- Don't check for null before `delete` - it's unnecessary

### Performance
- Cache expensive operations (file reads, complex calculations)
- Minimize operations in frequently called functions (`OnClientConnect`, etc.)
- Use efficient data structures (ArrayList vs arrays)

### Compatibility
- Use modern SourcePawn syntax for new code
- Maintain backward compatibility with existing API
- Test with minimum required SourceMod version (1.12+)

## Testing & Validation

### Local Testing
```bash
# Build the plugin
sourceknight build

# Check for compilation errors
# Output should be in .sourceknight/package/addons/sourcemod/plugins/
```

### Runtime Testing
- Test on a local SourceMod server
- Verify ban functionality with different CIDR ranges
- Test admin commands and permissions
- Check file I/O operations and error handling

### Integration Testing
- Test with MultiColors dependency
- Verify forward events work with other plugins
- Check compatibility with different SourceMod versions

## API Usage (CIDR.inc)

```sourcepawn
// Include the CIDR API
#include <CIDR>

// Forward declaration for ban events
public void CIDR_OnActionPerformed(int client, char[] sAction)
{
    // Handle ban notifications
    PrintToServer("CIDR Action: %s", sAction);
}
```

## Configuration

### ConVars
- `sm_cidr_path` - Path to ban list file (default: "configs/cidrblock.cfg")
- `sm_cidr_reject_message` - Message shown to banned users

### Admin Commands
- `sm_cidr_reload` - Reload ban list from file (ADMFLAG_ROOT)
- `sm_cidr_add` - Add CIDR ban (ADMFLAG_ROOT)

### File Format (cidrblock.cfg)
```
# Comments start with #
192.168.1.0/24 1609459200 PlayerName Reason: Cheating AdminName (STEAM_ID)
10.0.0.0/8 0 BadPlayer Reason: Griefing Console (<Console>)
```

## Development Workflow

1. **Make Changes**: Edit `.sp` files following style guidelines
2. **Build**: Run `sourceknight build` to compile
3. **Test**: Deploy to test server and verify functionality  
4. **Commit**: Use clear commit messages describing changes
5. **CI/CD**: Automatic building and release via GitHub Actions

## Common Modifications

### Adding New ConVars
```sourcepawn
// In OnPluginStart()
ConVar g_cvNewSetting = CreateConVar("sm_cidr_newsetting", "default", 
    "Description of the new setting");
AutoExecConfig(true);  // Save to config file
```

### Adding New Commands
```sourcepawn
// In OnPluginStart()
RegAdminCmd("sm_cidr_newcmd", Command_NewCmd, ADMFLAG_ROOT, 
    "Description of new command");

// Command handler
public Action Command_NewCmd(int client, int args)
{
    // Implementation
    return Plugin_Handled;
}
```

### Extending the API
```sourcepawn
// Add to CIDR.inc
native bool CIDR_IsClientBlocked(int client);

// Implement in CIDR.sp (OnPluginStart)
CreateNative("CIDR_IsClientBlocked", Native_IsClientBlocked);

// Native implementation
public int Native_IsClientBlocked(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return IsBlocked(client);
}
```

---

**Remember**: This plugin deals with network security. Always validate IP addresses, use proper error handling, and test thoroughly before deployment to production servers.