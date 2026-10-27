# The FetchContent arguments FindOrFetch.cmake builds for each argument form, written to PROBE_OUT. cmake
# -DHELPERS_DIR=<cmake_helpers> -DPROBE_OUT=<file> -P probe.cmake Every form runs with USE_FORCE_FETCH (no find_package)
# and the stand-in FetchContent of probe_modules/.
cmake_minimum_required(VERSION 3.25)
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/probe_modules")
file(WRITE "${PROBE_OUT}" "")
include("${HELPERS_DIR}/FindOrFetch.cmake")
set(USE_FORCE_FETCH ON)
set(CMAKE_CURRENT_BINARY_DIR "/bin-dir")

macro(form title)
    file(APPEND "${PROBE_OUT}" "== ${title}\n")
endmacro()

form("git, tag")
find_or_fetch_package(a GIT_REPOSITORY https://example.invalid/a.git GIT_TAG v1)
form("git, tag, shallow, subdir, quiet")
find_or_fetch_package(
    b
    QUIET
    GIT_REPOSITORY
    https://example.invalid/b.git
    GIT_TAG
    v2
    GIT_SHALLOW
    ON
    SOURCE_SUBDIR
    sub)
form("url + hash, git present but not chosen")
find_or_fetch_package(
    c
    DOWNLOAD_URL
    https://example.invalid/c.tar.gz
    DOWNLOAD_HASH
    SHA256=00
    GIT_REPOSITORY
    https://example.invalid/c.git
    GIT_TAG
    v3)
form("git chosen by USE_GIT_TAG")
set(USE_GIT_TAG ON)
find_or_fetch_package(
    d
    DOWNLOAD_URL
    https://example.invalid/d.tar.gz
    GIT_REPOSITORY
    https://example.invalid/d.git
    GIT_TAG
    v4)
set(USE_GIT_TAG OFF)
form("git branch by USE_GIT_BRANCH")
set(USE_GIT_BRANCH ON)
find_or_fetch_package(
    e
    GIT_REPOSITORY
    https://example.invalid/e.git
    GIT_TAG
    v5
    GIT_BRANCH
    main)
set(USE_GIT_BRANCH OFF)
form("git, patch file")
find_or_fetch_package(
    f
    GIT_REPOSITORY
    https://example.invalid/f.git
    GIT_TAG
    v6
    PATCH_FILE
    /p/f.patch)
form("url, patch and update command")
find_or_fetch_package(
    g
    DOWNLOAD_URL
    https://example.invalid/g.zip
    PATCH_COMMAND
    echo
    patch
    UPDATE_COMMAND
    echo
    up)
form("populate, git")
populate_package(h GIT_REPOSITORY https://example.invalid/h.git GIT_TAG v7)
form("populate, quiet, shallow, patch file, subdir")
populate_package(
    i
    QUIET
    GIT_REPOSITORY
    https://example.invalid/i.git
    GIT_TAG
    v8
    GIT_SHALLOW
    ON
    PATCH_FILE
    /p/i.patch
    SOURCE_SUBDIR
    sub)
form("populate, branch, patch command")
set(USE_GIT_BRANCH ON)
populate_package(
    j
    GIT_REPOSITORY
    https://example.invalid/j.git
    GIT_TAG
    v9
    GIT_BRANCH
    dev
    PATCH_COMMAND
    echo
    p)
set(USE_GIT_BRANCH OFF)
file(APPEND "${PROBE_OUT}" "j: ${j_SOURCE_DIR} ${j_BINARY_DIR} ${j_POPULATED}\n")
form("populate, pre-fetched source dir")
# an existing directory (a missing one is refused), written as <pre-k>
set(FETCHCONTENT_SOURCE_DIR_K "${CMAKE_CURRENT_LIST_DIR}/probe_modules")
populate_package(k GIT_REPOSITORY https://example.invalid/k.git GIT_TAG v10)
string(REPLACE "${FETCHCONTENT_SOURCE_DIR_K}" "<pre-k>" k_SOURCE_DIR "${k_SOURCE_DIR}")
file(APPEND "${PROBE_OUT}" "k: ${k_SOURCE_DIR} ${k_BINARY_DIR} ${k_POPULATED}\n")
