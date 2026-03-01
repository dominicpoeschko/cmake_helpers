#!/usr/bin/env python3
"""Generate a CycloneDX 1.6 SBOM by scanning a list of source directories.

Extracts git metadata (URL, commit SHA) and detects the SPDX license from each.

Usage:
    generate_sbom.py <output_file> <package_name> <package_version> \\
                     [--source-dir <dir>] <src_dir> [src_dir ...]

  --source-dir <dir>  Root source directory of the application being packaged.
                      Used to populate the metadata.component purl, license,
                      and VCS externalReference.
"""

import argparse
import hashlib
import json
import re
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from difflib import SequenceMatcher
from pathlib import Path
from urllib.parse import quote


def git(*args, cwd=None):
    """Run a git command, return stdout stripped, or '' on failure."""
    try:
        result = subprocess.run(
            ['git', *args],
            cwd=str(cwd) if cwd else None,
            capture_output=True, text=True
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except FileNotFoundError:
        pass
    return ''


_VERSION_FILES = [
    'VERSION', 'VERSION.txt', 'version', 'version.txt',
]

_VERSION_LINE_RE = re.compile(r'^v?(\d+\.\d+(?:\.\d+)*)$')


def detect_version(src_dir: Path) -> str:
    """Detect version: exact tag → project(VERSION …) → version file → short SHA."""
    tag = git('describe', '--tags', '--exact-match', 'HEAD', cwd=src_dir)
    if tag and re.match(r'^v?\d', tag):
        return tag

    cmake = src_dir / 'CMakeLists.txt'
    if cmake.is_file():
        text = cmake.read_text(errors='replace')
        m = re.search(
            r'\bproject\s*\([^)]*\bVERSION\s+([0-9]+\.[0-9]+(?:\.[0-9]+)*)',
            text, re.IGNORECASE | re.DOTALL
        )
        if m:
            return m.group(1)

    for name in _VERSION_FILES:
        vf = src_dir / name
        if vf.is_file():
            line = vf.read_text(errors='replace').strip().splitlines()[
                0].strip()
            m = _VERSION_LINE_RE.match(line)
            if m:
                return m.group(1)

    return git('rev-parse', '--short', 'HEAD', cwd=src_dir) or 'unknown'


_LICENSE_FILES = [
    'LICENSE', 'LICENSE.txt', 'LICENSE.md', 'LICENSE.rst', 'LICENSE.MIT',
    'LICENSE_1_0.txt', 'COPYING', 'COPYING.txt', 'LICENCE', 'LICENCE.txt',
]


def _normalize(text: str) -> str:
    """Normalize license text per SPDX matching guidelines."""
    lines = text.splitlines()[:100]
    result = []
    for line in lines:
        stripped = line.strip().lstrip('#*/>').strip()
        low = stripped.lower()
        if 'copyright' in low or '©' in low or '(c)' in low:
            continue
        result.append(stripped)
    combined = ' '.join(result).lower()
    return re.sub(r'\s+', ' ', combined).strip()


_LICENSE_REFS_RAW = {
    'MIT': """\
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.""",
    'Apache-2.0': """\
Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

1. Definitions.

"License" shall mean the terms and conditions for use, reproduction,
and distribution as defined by Sections 1 through 9 of this document.

"Licensor" shall mean the copyright owner or entity authorized by
the copyright owner that is granting the License.""",
    'GPL-3.0-only': """\
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.

Preamble

The GNU General Public License is a free, copyleft license for
software and other kinds of works.""",
    'GPL-2.0-only': """\
GNU GENERAL PUBLIC LICENSE
Version 2, June 1991

Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.

Preamble

The GNU General Public License is a free, copyleft license for
software and other kinds of works.""",
    'LGPL-3.0-only': """\
GNU LESSER GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.

This version of the GNU Lesser General Public License incorporates
the terms and conditions of version 3 of the GNU General Public
License, supplemented by the additional permissions listed below.""",
    'LGPL-2.1-only': """\
GNU LESSER GENERAL PUBLIC LICENSE
Version 2.1, February 1999

Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.

[This is the first released version of the Lesser GPL. It also counts
as the successor of the GNU Library Public License, version 2, hence
the version number 2.1.]

Preamble

The licenses for most software are designed to take away your
freedom to share and change it.""",
    'BSL-1.0': """\
Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.""",
    'BSD-3-Clause': """\
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors
   may be used to endorse or promote products derived from this software
   without specific prior written permission.""",
    'BSD-2-Clause': """\
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED.""",
    'MPL-2.0': """\
Mozilla Public License Version 2.0

1. Definitions

1.1. "Contributor"
    means each individual or legal entity that creates, maintains,
    or contributes to the creation of Covered Software.

1.2. "Contributor Version"
    means the combination of the Contributions of others (if any) used
    by a Contributor and that particular Contributor's Contribution.""",
    'Unlicense': """\
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain.""",
    'WTFPL': """\
DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
Version 2, December 2004

Everyone is permitted to copy and distribute verbatim or modified
copies of this license document, and changing it is allowed as long
as the name is changed.

DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

0. You just DO WHAT THE FUCK YOU WANT TO.""",
    'ISC': """\
ISC License

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.""",
}

_LICENSE_REFS = {spdx: _normalize(text)
                 for spdx, text in _LICENSE_REFS_RAW.items()}


def detect_license(src_dir: Path) -> str:
    license_file = None
    for name in _LICENSE_FILES:
        candidate = src_dir / name
        if candidate.is_file():
            license_file = candidate
            break
    if license_file is None:
        return 'NOASSERTION'

    text = license_file.read_text(errors='replace')

    # SPDX-License-Identifier tag
    for line in text.splitlines()[:20]:
        m = re.search(r'SPDX-License-Identifier:\s*(\S+)', line)
        if m:
            return m.group(1)

    # Similarity scoring against canonical SPDX reference snippets
    normalized = _normalize(text)
    best_id, best_score = None, 0.0
    for spdx_id, ref in _LICENSE_REFS.items():
        score = SequenceMatcher(None, normalized, ref).ratio()
        if score > best_score:
            best_id, best_score = spdx_id, score
    if best_score >= 0.5:
        return best_id

    # Fallback
    return 'LicenseRef-unknown'


def compute_checksum(src_dir: Path) -> str:
    """SHA-256 of the sorted concatenation of all file hashes (excluding .git)."""
    files = sorted(
        p for p in src_dir.rglob('*')
        if p.is_file() and '.git' not in p.parts
    )
    parts = []
    for f in files:
        h = hashlib.sha256(f.read_bytes()).hexdigest()
        parts.append(f'{h}  {f}')
    return hashlib.sha256('\n'.join(parts).encode()).hexdigest()


_GITHUB_RE = re.compile(r'github\.com[/:]([^/]+)/([^/.]+?)(?:\.git)?$')


def parse_github(repo_url: str):
    """Return (owner, repo) if it's a GitHub URL, else None."""
    m = _GITHUB_RE.search(repo_url)
    return (m.group(1), m.group(2)) if m else None


def build_purl(repo_url: str, commit_sha: str) -> str:
    gh = parse_github(repo_url)
    if gh:
        owner, repo = gh
        return f'pkg:github/{owner}/{repo}@{commit_sha}'
    repo_name = Path(repo_url).stem  # strip .git
    return f'pkg:generic/{repo_name}@{commit_sha}?vcs_url={quote(repo_url, safe="")}'


def build_commit_url(repo_url: str, commit_sha: str):
    """Return a GitHub commit URL, or None for non-GitHub repos."""
    gh = parse_github(repo_url)
    if gh:
        owner, repo = gh
        return f'https://github.com/{owner}/{repo}/commit/{commit_sha}'
    return None


def common_prefix(names):
    prefix = names[0]
    for s in names[1:]:
        while not s.startswith(prefix):
            prefix = prefix[:-1]
    return prefix.rstrip('_-')


def common_suffix(names):
    suffix = names[0]
    for s in names[1:]:
        while not s.endswith(suffix):
            suffix = suffix[1:]
    return suffix.lstrip('_-')


def pick_canonical(names: list) -> str:
    if len(names) == 1:
        return names[0]

    prefix = common_prefix(names)
    suffix = common_suffix(names)
    candidate = prefix if len(prefix) >= len(suffix) else suffix

    if candidate in names:
        return candidate

    return min(names, key=lambda n: (len(n), n))


def build_component(canonical: str, version: str, purl: str, repo_url: str,
                    license_id: str, checksum: str, commit_sha: str) -> dict:
    comp = {
        'type': 'library',
        'bom-ref': canonical,
        'name': canonical,
        'version': version,
        'scope': 'required',
    }

    gh = parse_github(purl)
    if gh:
        org = gh[0]
        comp['supplier'] = {'name': org, 'url': [f'https://github.com/{org}']}

    comp['purl'] = purl
    comp['hashes'] = [{'alg': 'SHA-256', 'content': checksum}]

    if license_id not in ('NOASSERTION', 'LicenseRef-unknown'):
        comp['licenses'] = [
            {'license': {'id': license_id, 'acknowledgement': 'concluded'}}]

    vcs_ref = {'type': 'vcs', 'url': repo_url}
    if re.fullmatch(r'[0-9a-f]{40}', commit_sha):
        vcs_ref['hashes'] = [{'alg': 'SHA-1', 'content': commit_sha}]
    comp['externalReferences'] = [vcs_ref]

    commit_entry = {'uid': commit_sha}
    commit_url = build_commit_url(repo_url, commit_sha)
    if commit_url:
        commit_entry['url'] = commit_url
    comp['pedigree'] = {'commits': [commit_entry]}

    return comp


def build_root_component(package_name: str, package_version: str, source_dir: Path) -> dict:
    comp = {
        'type': 'application',
        'bom-ref': package_name,
        'name': package_name,
        'version': package_version,
        'description': 'CMake FetchContent dependency package',
    }

    if not (source_dir and source_dir.is_dir()):
        return comp

    license_id = detect_license(source_dir)
    if license_id not in ('NOASSERTION', 'LicenseRef-unknown'):
        comp['licenses'] = [
            {'license': {'id': license_id, 'acknowledgement': 'declared'}}]

    if (source_dir / '.git').is_dir():
        repo_url = git('remote', 'get-url', 'origin', cwd=source_dir)
        commit_sha = git('rev-parse', 'HEAD', cwd=source_dir)

        if repo_url:
            gh = parse_github(repo_url)
            if gh:
                owner, repo = gh
                comp['purl'] = f'pkg:github/{owner}/{repo}@{commit_sha}'
            else:
                repo_name = Path(repo_url).stem
                comp['purl'] = f'pkg:generic/{repo_name}@{commit_sha}?vcs_url={quote(repo_url, safe="")}'

            vcs_ref = {'type': 'vcs', 'url': repo_url}
            if re.fullmatch(r'[0-9a-f]{40}', commit_sha):
                vcs_ref['hashes'] = [{'alg': 'SHA-1', 'content': commit_sha}]
            comp['externalReferences'] = [vcs_ref]

    return comp


def main():
    parser = argparse.ArgumentParser(
        description='Generate a CycloneDX 1.6 SBOM from CMake FetchContent source dirs.'
    )
    parser.add_argument('output_file', help='Path to write sbom.json')
    parser.add_argument('package_name', help='Name of the top-level package')
    parser.add_argument('package_version',
                        help='Version of the top-level package')
    parser.add_argument('--source-dir', metavar='DIR',
                        help='Root source dir of the application (for metadata.component)')
    parser.add_argument('src_dirs', nargs='+', metavar='src_dir',
                        help='Source directories to include as components')
    args = parser.parse_args()

    source_dir = Path(args.source_dir) if args.source_dir else None

    ordered_names = []
    all_data = {}  # name → {purl, version, repo_url, commit_sha, license, checksum}

    for src_str in args.src_dirs:
        src_dir = Path(src_str)
        if not src_dir.is_dir():
            print(
                f'WARNING: {src_dir} is not a directory — skipping', file=sys.stderr)
            continue

        name = src_dir.name.removesuffix('-src')
        if name in all_data:
            continue

        if not (src_dir / '.git').is_dir():
            print(
                f'  WARNING: {name} has no .git — omitted from SBOM', file=sys.stderr)
            continue

        repo_url = git('remote', 'get-url', 'origin', cwd=src_dir) or 'unknown'
        commit_sha = git('rev-parse', 'HEAD', cwd=src_dir) or 'unknown'
        version = detect_version(src_dir)
        checksum = compute_checksum(src_dir)
        license_id = detect_license(src_dir)
        purl = build_purl(repo_url, commit_sha)

        ordered_names.append(name)
        all_data[name] = {
            'purl': purl,
            'version': version,
            'repo_url': repo_url,
            'commit_sha': commit_sha,
            'license': license_id,
            'checksum': checksum,
        }

    purl_groups: dict[str, list[str]] = {}
    for name in ordered_names:
        purl_groups.setdefault(all_data[name]['purl'], []).append(name)

    purl_canonical = {purl: pick_canonical(
        names) for purl, names in purl_groups.items()}

    components = []
    emitted_purls: set[str] = set()
    emitted_canonicals: list[str] = []

    for name in ordered_names:
        purl = all_data[name]['purl']
        if purl in emitted_purls:
            continue
        emitted_purls.add(purl)

        canonical = purl_canonical[purl]
        emitted_canonicals.append(canonical)

        for alias in purl_groups[purl]:
            if alias != canonical:
                print(f"  {alias}: alias of '{canonical}' — skipping",
                      file=sys.stderr)

        cd = all_data[canonical]
        print(
            f"  {canonical}: {cd['version']} ({cd['license']})", file=sys.stderr)

        components.append(build_component(
            canonical=canonical,
            version=cd['version'],
            purl=purl,
            repo_url=cd['repo_url'],
            license_id=cd['license'],
            checksum=cd['checksum'],
            commit_sha=cd['commit_sha'],
        ))

    root_comp = build_root_component(
        args.package_name, args.package_version, source_dir)

    timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    serial = str(uuid.uuid4())

    dependencies = [
        {'ref': args.package_name, 'dependsOn': emitted_canonicals},
        *[{'ref': cn, 'dependsOn': []} for cn in emitted_canonicals],
    ]

    sbom = {
        'bomFormat': 'CycloneDX',
        'specVersion': '1.6',
        'version': 1,
        'serialNumber': f'urn:uuid:{serial}',
        'metadata': {
            'timestamp': timestamp,
            'lifecycles': [{'phase': 'build'}],
            'tools': {
                'components': [
                    {'type': 'application', 'name': 'generate_sbom.py'}
                ]
            },
            'component': root_comp,
        },
        'components': components,
        'dependencies': dependencies,
        'compositions': [
            {
                'aggregate': 'incomplete',
                'assemblies': [args.package_name, *emitted_canonicals],
            }
        ],
    }

    output = Path(args.output_file)
    output.write_text(json.dumps(sbom, indent=2) + '\n')
    print(f'SBOM generated: {output}')


if __name__ == '__main__':
    main()
