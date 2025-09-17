#!/bin/bash
# Check for upstream updates to ham radio packages
# Built for the Amateur Radio community by Andy Taylor (MW0MWZ)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to get latest commit from GitHub
get_github_commit() {
    local url=$1
    local repo=$(echo "$url" | sed 's|.*github.com/||' | sed 's|\.git$||')
    
    # Try to get latest commit from default branch
    for branch in main master develop; do
        commit=$(curl -s -H "Accept: application/vnd.github.v3+json" \
            ${GITHUB_TOKEN:+-H "Authorization: token $GITHUB_TOKEN"} \
            "https://api.github.com/repos/${repo}/commits/${branch}" 2>/dev/null | \
            grep '"sha"' | head -1 | cut -d'"' -f4 | cut -c1-7)
        
        if [ -n "$commit" ]; then
            echo "$commit"
            return
        fi
    done
    
    echo ""
}

# Function to check a single package
check_package() {
    local package=$1
    local apkbuild="packages/community/${package}/APKBUILD"
    
    if [ ! -f "$apkbuild" ]; then
        echo -e "${RED}✗${NC} $package: APKBUILD not found"
        return 1
    fi
    
    # Get git URL from APKBUILD (try multiple patterns)
    local giturl=$(grep "^giturl=" "$apkbuild" 2>/dev/null | head -1 | cut -d'"' -f2)
    
    # Try alternative patterns if giturl not found
    if [ -z "$giturl" ]; then
        giturl=$(grep "_giturl=" "$apkbuild" 2>/dev/null | head -1 | cut -d'"' -f2)
    fi
    
    if [ -z "$giturl" ]; then
        echo -e "${YELLOW}⚠${NC}  $package: No git URL found"
        return 1
    fi
    
    # Get current commit from APKBUILD
    local current_commit=$(grep "^_gitcommit=" "$apkbuild" | cut -d'"' -f2)
    
    if [ -z "$current_commit" ]; then
        echo -e "${YELLOW}⚠${NC}  $package: No current commit found"
        return 1
    fi
    
    echo -n "$package: "
    
    # Get latest commit from upstream
    local latest_commit=$(get_github_commit "$giturl")
    
    if [ -z "$latest_commit" ]; then
        echo -e "${YELLOW}⚠${NC}  Could not fetch latest commit"
        return 1
    fi
    
    # Compare commits
    if [ "$current_commit" = "$latest_commit" ]; then
        echo -e "${GREEN}✓${NC} Up to date ($current_commit)"
        return 1
    else
        echo -e "${RED}↻${NC} Update available: $current_commit → $latest_commit"
        echo "  Repository: $giturl"
        return 0
    fi
}

# Function to update APKBUILD with new commit
update_apkbuild() {
    local package=$1
    local new_commit=$2
    local apkbuild="packages/community/${package}/APKBUILD"
    
    if [ ! -f "$apkbuild" ]; then
        echo "Error: APKBUILD not found for $package"
        return 1
    fi
    
    # Update _gitcommit in APKBUILD
    sed -i "s/^_gitcommit=.*/_gitcommit=\"${new_commit}\"/" "$apkbuild"
    
    echo "Updated $package to commit $new_commit"
}

# Main script
main() {
    local UPDATE_MODE=false
    local PACKAGES=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --update)
                UPDATE_MODE=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--update] [package1 package2 ...]"
                echo ""
                echo "Check for upstream updates to ham radio packages"
                echo ""
                echo "Options:"
                echo "  --update    Update APKBUILD files with new commits"
                echo "  --help      Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                    # Check all packages"
                echo "  $0 mmdvmhost          # Check specific package"
                echo "  $0 --update           # Check all and update APKBUILDs"
                exit 0
                ;;
            *)
                PACKAGES="$PACKAGES $1"
                shift
                ;;
        esac
    done
    
    # Determine which packages to check
    if [ -z "$PACKAGES" ]; then
        # Find all packages
        PACKAGES=$(find packages/community -maxdepth 1 -type d -exec basename {} \; | grep -v community | sort)
    fi
    
    echo "Checking for upstream updates..."
    echo "================================"
    echo ""
    
    local UPDATES_FOUND=""
    local UPDATE_COUNT=0
    
    # Check each package
    for package in $PACKAGES; do
        if check_package "$package"; then
            UPDATE_COUNT=$((UPDATE_COUNT + 1))
            
            # If in update mode, get the latest commit and update
            if [ "$UPDATE_MODE" = true ]; then
                apkbuild="packages/community/${package}/APKBUILD"
                giturl=$(grep -E "(_)?giturl=" "$apkbuild" | head -1 | cut -d'"' -f2)
                latest_commit=$(get_github_commit "$giturl")
                
                if [ -n "$latest_commit" ]; then
                    update_apkbuild "$package" "$latest_commit"
                    UPDATES_FOUND="$UPDATES_FOUND $package"
                fi
            else
                UPDATES_FOUND="$UPDATES_FOUND $package"
            fi
        fi
    done
    
    # Summary
    echo ""
    echo "================================"
    if [ $UPDATE_COUNT -gt 0 ]; then
        echo -e "${YELLOW}Found $UPDATE_COUNT package(s) with updates:${NC}"
        for pkg in $UPDATES_FOUND; do
            echo "  • $pkg"
        done
        
        if [ "$UPDATE_MODE" = true ]; then
            echo ""
            echo -e "${GREEN}APKBUILD files updated!${NC}"
            echo "Remember to commit the changes:"
            echo "  git add packages/community/*/APKBUILD"
            echo "  git commit -m 'Update packages to latest upstream commits'"
        else
            echo ""
            echo "Run with --update to update the APKBUILD files"
        fi
    else
        echo -e "${GREEN}All packages are up to date!${NC}"
    fi
    
    # Exit with appropriate code for CI
    if [ $UPDATE_COUNT -gt 0 ]; then
        exit 0  # Updates found (success for workflow)
    else
        exit 0  # No updates (also success, just no action needed)
    fi
}

# Run main function
main "$@"