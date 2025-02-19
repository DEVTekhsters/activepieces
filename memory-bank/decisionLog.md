## 2025-02-13 - Air-Gapped Deployment Requirements

**Context:** 
Review of Dockerfile revealed need for changes to support air-gapped deployment ensuring all 5 community pieces (http, csv, whatsapp, airtable, gmail) are locally packaged.

**Analysis:**
1. Current Issues:
   - External CDN dependencies for piece logos
   - Runtime API calls to external services
   - Dependencies fetched during build/runtime

**Required Changes:**
1. Build Process Modifications:
   - Pre-install all dependencies during build
   - Package all piece resources locally
   - Copy piece logos to local assets directory
   - Ensure no external downloads during runtime

2. Environment Configuration:
   - AP_PIECES_SOURCE=FILE (currently set)
   - AP_PIECES_SYNC_MODE=NONE (currently set)
   - New env var AP_ASSETS_BASE_URL for local assets

3. Local Asset Management:
   - Create local assets directory
   - Copy all required piece logos
   - Update piece configurations to use local assets

**Implementation Plan:**
1. Switch to Code mode to modify Dockerfile
2. Add local assets directory setup
3. Copy piece logos during build
4. Configure environment for local assets
5. Verify all dependencies are pre-installed

**Next Steps:**
Switching to Code mode to implement these changes.