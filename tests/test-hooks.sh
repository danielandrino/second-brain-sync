#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRE_COMMIT_HOOK="$REPO_ROOT/hooks/pre-commit"
POST_COMMIT_HOOK="$REPO_ROOT/hooks/post-commit"

TMPDIR_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/second-brain-sync-tests.XXXXXX")"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

TESTS_RUN=0

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$actual" != "$expected" ]]; then
        echo "Expected:" >&2
        printf '%s\n' "$expected" >&2
        echo "Actual:" >&2
        printf '%s\n' "$actual" >&2
        fail "$message"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    if [[ "$haystack" != *"$needle"* ]]; then
        echo "Output did not contain: $needle" >&2
        echo "$haystack" >&2
        fail "$message"
    fi
}

new_repo() {
    local name="$1"
    local dir="$TMPDIR_ROOT/$name"

    mkdir -p "$dir"
    git init -q "$dir"
    git -C "$dir" config user.name "Test User"
    git -C "$dir" config user.email "test@example.com"
    mkdir -p "$dir/internal" "$dir/external" "$dir/.git/hooks"
    cp "$PRE_COMMIT_HOOK" "$dir/.git/hooks/pre-commit"
    cp "$POST_COMMIT_HOOK" "$dir/.git/hooks/post-commit"
    chmod +x "$dir/.git/hooks/pre-commit" "$dir/.git/hooks/post-commit"
    printf '%s\n' "$dir"
}

run_pre_commit() {
    local repo="$1"
    local output_file="$repo/pre-commit.out"

    set +e
    (
        cd "$repo"
        export SECOND_BRAIN_DIR="$repo/external"
        .git/hooks/pre-commit
    ) >"$output_file" 2>&1
    PRE_COMMIT_EXIT=$?
    set -e
    PRE_COMMIT_OUTPUT="$(cat "$output_file")"
}

run_test() {
    local name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    echo "[$TESTS_RUN] $name"
    "$name"
}

test_pre_commit_merges_non_overlapping_text_changes() {
    local repo
    repo="$(new_repo merge_clean)"

    cat >"$repo/internal/doc.txt" <<'EOF'
line1
line2
line3
EOF
    cp "$repo/internal/doc.txt" "$repo/external/doc.txt"

    git -C "$repo" add internal/doc.txt
    SECOND_BRAIN_DIR="$repo/external" git -C "$repo" commit -q -m "base"

    cat >"$repo/internal/doc.txt" <<'EOF'
line1
internal
line2
line3
EOF
    git -C "$repo" add internal/doc.txt

    cat >"$repo/external/doc.txt" <<'EOF'
line1
line2
line3
external
EOF

    run_pre_commit "$repo"
    assert_eq "0" "$PRE_COMMIT_EXIT" "pre-commit should merge clean text changes"

    local staged
    staged="$(git -C "$repo" show :internal/doc.txt)"
    assert_eq "$(cat <<'EOF'
line1
internal
line2
line3
external
EOF
)" "$staged" "merged staged content should include both changes"
}

test_pre_commit_rejects_unstaged_internal_changes() {
    local repo
    repo="$(new_repo unstaged_conflict)"

    printf 'base\n' >"$repo/internal/doc.txt"
    printf 'base\n' >"$repo/external/doc.txt"
    git -C "$repo" add internal/doc.txt
    SECOND_BRAIN_DIR="$repo/external" git -C "$repo" commit -q -m "base"

    printf 'staged\n' >"$repo/internal/doc.txt"
    git -C "$repo" add internal/doc.txt
    printf 'unstaged\n' >"$repo/internal/doc.txt"
    printf 'external\n' >"$repo/external/doc.txt"

    run_pre_commit "$repo"
    assert_eq "1" "$PRE_COMMIT_EXIT" "pre-commit should abort when unstaged changes would be overwritten"
    assert_contains "$PRE_COMMIT_OUTPUT" "cannot merge while internal/ has unstaged local changes" "pre-commit should explain unstaged-change conflict"

    local staged
    staged="$(git -C "$repo" show :internal/doc.txt)"
    assert_eq "staged" "$staged" "pre-commit must not rewrite the staged blob"

    local worktree
    worktree="$(cat "$repo/internal/doc.txt")"
    assert_eq "unstaged" "$worktree" "pre-commit must not rewrite the worktree file"
}

test_pre_commit_syncs_external_change_into_index() {
    local repo
    repo="$(new_repo external_sync)"

    printf 'base\n' >"$repo/internal/doc.txt"
    printf 'base\n' >"$repo/external/doc.txt"
    git -C "$repo" add internal/doc.txt
    SECOND_BRAIN_DIR="$repo/external" git -C "$repo" commit -q -m "base"

    printf 'external\n' >"$repo/external/doc.txt"

    run_pre_commit "$repo"
    assert_eq "0" "$PRE_COMMIT_EXIT" "pre-commit should sync external-only changes"

    local staged
    staged="$(git -C "$repo" show :internal/doc.txt)"
    assert_eq "external" "$staged" "external-only change should be staged into internal/"
}

test_post_commit_syncs_root_commit() {
    local repo
    repo="$(new_repo root_sync)"

    printf 'first\n' >"$repo/internal/doc.txt"
    (
        cd "$repo"
        export SECOND_BRAIN_DIR="$repo/external"
        git add internal/doc.txt
        git commit -q -m "root"
    )

    local mirrored
    mirrored="$(cat "$repo/external/doc.txt")"
    assert_eq "first" "$mirrored" "post-commit should mirror files on the initial commit"
}

test_pre_commit_treats_plain_text_as_text() {
    local repo
    repo="$(new_repo text_detection)"

    cat >"$repo/internal/doc.txt" <<'EOF'
alpha
beta
gamma
EOF
    cp "$repo/internal/doc.txt" "$repo/external/doc.txt"

    git -C "$repo" add internal/doc.txt
    SECOND_BRAIN_DIR="$repo/external" git -C "$repo" commit -q -m "base"

    cat >"$repo/internal/doc.txt" <<'EOF'
alpha
internal
beta
gamma
EOF
    git -C "$repo" add internal/doc.txt

    cat >"$repo/external/doc.txt" <<'EOF'
alpha
beta
gamma
external
EOF

    run_pre_commit "$repo"
    assert_eq "0" "$PRE_COMMIT_EXIT" "plain text files should not be treated as binary"
    assert_contains "$PRE_COMMIT_OUTPUT" "auto-merged" "plain text divergence should use the text merge path"
}

main() {
    run_test test_pre_commit_merges_non_overlapping_text_changes
    run_test test_pre_commit_rejects_unstaged_internal_changes
    run_test test_pre_commit_syncs_external_change_into_index
    run_test test_post_commit_syncs_root_commit
    run_test test_pre_commit_treats_plain_text_as_text
    echo "PASS: $TESTS_RUN tests"
}

main "$@"
