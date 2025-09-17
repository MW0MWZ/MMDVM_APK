#!/usr/bin/env python3
"""
Check upstream repositories for updates to ham radio packages.
This script checks GitHub repositories for newer commits than what's in the APKBUILDs.

Built for the Amateur Radio community by Andy Taylor (MW0MWZ)
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import urllib.request
import urllib.error

class UpstreamChecker:
    def __init__(self):
        self.packages_dir = Path("packages/community")
        self.github_token = os.environ.get("GITHUB_TOKEN", "")
        
    def get_github_headers(self) -> Dict[str, str]:
        """Get headers for GitHub API requests."""
        headers = {"Accept": "application/vnd.github.v3+json"}
        if self.github_token:
            headers["Authorization"] = f"token {self.github_token}"
        return headers
    
    def get_github_latest_commit(self, repo_url: str) -> Optional[str]:
        """Get the latest commit SHA from GitHub."""
        # Extract owner and repo from URL
        match = re.search(r'github\.com/([^/]+)/([^/]+)', repo_url)
        if not match:
            return None
        
        owner, repo = match.groups()
        repo = repo.replace('.git', '')
        
        # Try main, master, and develop branches
        branches = ["main", "master", "develop"]
        
        for branch in branches:
            api_url = f"https://api.github.com/repos/{owner}/{repo}/commits/{branch}"
            
            try:
                req = urllib.request.Request(api_url)
                for key, value in self.get_github_headers().items():
                    req.add_header(key, value)
                
                with urllib.request.urlopen(req, timeout=10) as response:
                    if response.status == 200:
                        data = json.loads(response.read().decode())
                        # Return first 7 chars like the APKBUILD uses
                        return data.get('sha', '')[:7]
            except (urllib.error.URLError, urllib.error.HTTPError) as e:
                continue
            except Exception as e:
                print(f"Error checking {repo} branch {branch}: {e}", file=sys.stderr)
                continue
        
        return None
    
    def parse_apkbuild(self, apkbuild_path: Path) -> Dict[str, str]:
        """Parse APKBUILD file to extract package information."""
        content = apkbuild_path.read_text()
        
        info = {}
        
        # Extract package name
        match = re.search(r'^pkgname=(.+?)$', content, re.MULTILINE)
        if match:
            info['pkgname'] = match.group(1).strip('"\'')
        
        # Extract current git commit
        match = re.search(r'^_gitcommit="?([^"\s]+)"?$', content, re.MULTILINE)
        if match:
            info['current_commit'] = match.group(1)
        
        # Extract git URL - try multiple patterns
        patterns = [
            r'^giturl="?([^"\s]+)"?$',
            r'^_giturl="?([^"\s]+)"?$',
            r'^[a-z]+_giturl="?([^"\s]+)"?$',  # e.g., mmdvm_cm_giturl, dmrgateway_giturl
        ]
        
        for pattern in patterns:
            match = re.search(pattern, content, re.MULTILINE)
            if match:
                info['giturl'] = match.group(1)
                break
        
        return info
    
    def check_package(self, package_dir: Path) -> Optional[Dict]:
        """Check if a package needs updating."""
        apkbuild_path = package_dir / "APKBUILD"
        if not apkbuild_path.exists():
            return None
        
        info = self.parse_apkbuild(apkbuild_path)
        package_name = info.get('pkgname', package_dir.name)
        current_commit = info.get('current_commit', '')
        giturl = info.get('giturl', '')
        
        if not giturl:
            print(f"No git URL found for {package_name}", file=sys.stderr)
            return None
        
        if not current_commit:
            print(f"No current commit found for {package_name}", file=sys.stderr)
            return None
        
        print(f"Checking {package_name}...")
        print(f"  Repository: {giturl}")
        print(f"  Current commit: {current_commit}")
        
        # Get latest commit from GitHub
        latest_commit = self.get_github_latest_commit(giturl)
        
        if not latest_commit:
            print(f"  Could not fetch latest commit", file=sys.stderr)
            return None
        
        print(f"  Latest commit:  {latest_commit}")
        
        # Check if update is needed
        if current_commit != latest_commit:
            print(f"  >>> UPDATE AVAILABLE!")
            return {
                'package': package_name,
                'current_commit': current_commit,
                'latest_commit': latest_commit,
                'giturl': giturl
            }
        else:
            print(f"  Up to date")
            return None
    
    def check_all_packages(self, specific_packages: List[str] = None) -> List[Dict]:
        """Check packages for updates."""
        updates = []
        
        if not self.packages_dir.exists():
            print(f"Packages directory not found: {self.packages_dir}", file=sys.stderr)
            return updates
        
        # Determine which packages to check
        if specific_packages:
            package_dirs = [self.packages_dir / pkg for pkg in specific_packages]
        else:
            package_dirs = sorted([d for d in self.packages_dir.iterdir() if d.is_dir()])
        
        for package_dir in package_dirs:
            if package_dir.is_dir() and package_dir.exists():
                update_info = self.check_package(package_dir)
                if update_info:
                    updates.append(update_info)
                print()  # Empty line between packages
        
        return updates
    
    def update_apkbuild(self, package_name: str, new_commit: str) -> bool:
        """Update APKBUILD file with new commit."""
        apkbuild_path = self.packages_dir / package_name / "APKBUILD"
        
        if not apkbuild_path.exists():
            print(f"APKBUILD not found: {apkbuild_path}", file=sys.stderr)
            return False
        
        content = apkbuild_path.read_text()
        
        # Update _gitcommit
        updated_content = re.sub(
            r'^_gitcommit="?[^"\s]+"?$',
            f'_gitcommit="{new_commit}"',
            content,
            flags=re.MULTILINE
        )
        
        if updated_content != content:
            apkbuild_path.write_text(updated_content)
            print(f"Updated {package_name} APKBUILD to commit {new_commit}")
            return True
        else:
            print(f"Failed to update {package_name} APKBUILD", file=sys.stderr)
            return False

def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Check for upstream updates to packages')
    parser.add_argument('packages', nargs='*', help='Specific packages to check (default: all)')
    parser.add_argument('--update', action='store_true', help='Update APKBUILD files with new commits')
    parser.add_argument('--json', action='store_true', help='Output results as JSON')
    
    args = parser.parse_args()
    
    checker = UpstreamChecker()
    
    # Check for updates
    updates = checker.check_all_packages(args.packages if args.packages else None)
    
    if args.json:
        # Output as JSON for scripting
        print(json.dumps(updates, indent=2))
    else:
        # Summary
        print("=" * 60)
        if updates:
            print(f"Found {len(updates)} package(s) with updates:")
            for update in updates:
                print(f"  - {update['package']}: {update['current_commit']} -> {update['latest_commit']}")
            
            if args.update:
                print("\nUpdating APKBUILD files...")
                for update in updates:
                    checker.update_apkbuild(update['package'], update['latest_commit'])
                print("\nDone! Remember to commit the changes.")
            else:
                print("\nRun with --update to update the APKBUILD files")
        else:
            print("All packages are up to date!")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())