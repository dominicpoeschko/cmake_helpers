#!/usr/bin/env python3
"""Package all FetchContent dependencies from a CMake project for offline use.

Configures the CMake project in a build directory (triggering FetchContent to
download all dependencies), then copies all fetched *-src directories into an
output package and generates a CMake preload file with FETCHCONTENT_SOURCE_DIR_*
variables for each dependency, enabling fully offline builds.

Usage:
    package_cmake_deps.py [--sbom] [--work-dir <dir>] [name]
    OUTPUT_DIR=/path/to/output package_cmake_deps.py [options] [name]

  --sbom              Generate a CycloneDX 1.6 SBOM (sbom.json) alongside the package.
  --work-dir <dir>    Use <dir> as the CMake build directory instead of a temp dir.
                      The directory is NOT deleted on exit, making subsequent runs faster
                      (CMake reuses the already-fetched sources).
"""

import argparse
import filecmp
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def git(*args, cwd=None):
    """Run a git command, return stdout stripped, or '' on failure."""
    try:
        result = subprocess.run(
            ['git', *args],
            cwd=str(cwd) if cwd else None,
            capture_output=True, text=True,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except FileNotFoundError:
        pass
    return ''


def dirs_equal(a: Path, b: Path) -> bool:
    """Deep equality check, ignoring .git and .github trees."""
    cmp = filecmp.dircmp(str(a), str(b), hide=['.git', '.github'])
    if cmp.diff_files or cmp.left_only or cmp.right_only:
        return False
    return all(dirs_equal(a / sub, b / sub) for sub in cmp.common_dirs)


def main():
    parser = argparse.ArgumentParser(
        description='Package CMake FetchContent dependencies for offline use.'
    )
    parser.add_argument('name', nargs='?', default='offline',
                        help='Package name (default: offline)')
    parser.add_argument('--sbom', action='store_true',
                        help='Generate a CycloneDX 1.6 SBOM (sbom.json)')
    parser.add_argument('--work-dir', metavar='DIR',
                        help='CMake build directory (kept between runs; skips temp dir)')
    args = parser.parse_args()

    source_dir = Path.cwd()
    name = args.name
    output_dir = Path(os.environ.get(
        'OUTPUT_DIR', source_dir / f'{name}_package'))

    tmp_dir = None
    if args.work_dir:
        build_dir = Path(args.work_dir)
        build_dir.mkdir(parents=True, exist_ok=True)
    else:
        tmp_dir = tempfile.mkdtemp()
        build_dir = Path(tmp_dir)

    try:
        print(f'=== Creating Package: {name} ===')
        print(f'Source:    {source_dir}')
        print(f'Build dir: {build_dir}')

        if output_dir.exists():
            shutil.rmtree(output_dir)
        output_dir.mkdir(parents=True)

        print('Fetching dependencies via CMake...')
        subprocess.run(
            [
                'cmake',
                '-S', str(source_dir),
                '-B', str(build_dir),
                '-DUSE_FORCE_FETCH=ON',
                '-DUSE_GIT_TAG=ON',
            ],
            check=True,
        )

        if args.sbom:
            print('Generating SBOM...')
            pkg_version = (
                git('describe', '--tags', '--exact-match', 'HEAD', cwd=source_dir)
                or git('rev-parse', '--short', 'HEAD', cwd=source_dir)
                or 'unknown'
            )
            sbom_dirs = sorted(
                p for p in build_dir.rglob('*-src')
                if p.is_dir()
                and '_deps' in p.parts
                and 'CMakeFiles' not in p.parts
            )
            sbom_script = Path(__file__).parent / 'generate_sbom.py'
            subprocess.run(
                [
                    sys.executable, str(sbom_script),
                    str(output_dir / 'sbom.json'),
                    name,
                    pkg_version,
                    '--source-dir', str(source_dir),
                    *[str(d) for d in sbom_dirs],
                ],
                check=True,
            )

        print('Copying dependencies...')
        src_dirs = sorted(
            p for p in build_dir.rglob('*-src')
            if p.is_dir()
            and '_deps' in p.parts
            and 'CMakeFiles' not in p.parts
        )

        copied_deps: dict[str, Path] = {}  # name → first source path seen

        for src_dir in src_dirs:
            dep_name = src_dir.name.removesuffix('-src')
            dst = output_dir / dep_name

            if dep_name in copied_deps:
                if dirs_equal(copied_deps[dep_name], src_dir):
                    print(f'  {dep_name} (skipped, duplicate)')
                    continue
                print(f'ERROR: Duplicate dependency {dep_name!r} with different content:',
                      file=sys.stderr)
                print(f'  First:  {copied_deps[dep_name]}', file=sys.stderr)
                print(f'  Second: {src_dir}', file=sys.stderr)
                sys.exit(1)

            print(f'  {dep_name}')
            shutil.copytree(
                src_dir, dst,
                ignore=shutil.ignore_patterns('.git', '.github'),
            )
            copied_deps[dep_name] = src_dir

        if not copied_deps:
            print('ERROR: No dependencies found', file=sys.stderr)
            sys.exit(1)

        preload_file = output_dir / f'{name}_preload.cmake'
        print(f'Generating {preload_file.name}...')
        lines = [f'# Autogenerated preload for {name}']
        for dep_name in sorted(copied_deps):
            upper = dep_name.upper()
            lines.append(
                f'set(FETCHCONTENT_SOURCE_DIR_{upper} '
                f'"${{CMAKE_CURRENT_LIST_DIR}}/{dep_name}" CACHE PATH "")'
            )
        lines.append('')
        lines.append('set(FETCHCONTENT_FULLY_DISCONNECTED ON CACHE BOOL "")')
        lines.append('set(USE_FORCE_FETCH ON CACHE BOOL "")')
        preload_file.write_text('\n'.join(lines) + '\n')

        print('=== Done ===')
        print(f'Copied {len(copied_deps)} dependencies to: {output_dir}')
        print(f'Preload file: {preload_file}')
        if args.work_dir:
            print(f'Build dir kept: {build_dir}')
        print()
        print(f'Usage: cmake -C {preload_file} ...')

    finally:
        if tmp_dir:
            shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == '__main__':
    main()
