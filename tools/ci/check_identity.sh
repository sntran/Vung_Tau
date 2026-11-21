#!/usr/bin/env bash
# Each commit of the branch has the identity of CONTRIBUTING.md, as author and
# as committer (report 0026, D-0026-43).
#
#     tools/ci/check_identity.sh [BASE [TIP]]
#
# BASE is the branch that the branch goes to (default origin/main), and TIP is
# the last commit of the branch (default HEAD). The check reads the commits of
# BASE..TIP, also the merge commits, and fails when one has another name or
# address.
set -euo pipefail
cd "$(dirname "$0")/../.."
base="${1:-origin/main}"
tip="${2:-HEAD}"
line=$(grep -m1 -o 'git -c user.name="[^"]*" -c user.email=[^ ]*' CONTRIBUTING.md)
name=$(sed -E 's/.*user.name="([^"]*)".*/\1/' <<<"$line")
email=$(sed -E 's/.*user.email=([^ ]*).*/\1/' <<<"$line")
if [ -z "$name" ] || [ -z "$email" ]; then
	echo "check_identity.sh: CONTRIBUTING.md has no identity" >&2
	exit 2
fi
expected="$name <$email>"
count=$(git rev-list --count "$base..$tip")
bad=$(git log --format='%h %an <%ae> | %cn <%ce> | %s' "$base..$tip" |
	awk -F' [|] ' -v want="$expected" '{ split($1, a, " "); author = substr($1, length(a[1]) + 2); if (author != want || $2 != want) print }')
if [ -n "$bad" ]; then
	echo "check_identity.sh: these commits of $base..$tip are not of $expected (author | committer | subject):"
	echo "$bad"
	exit 1
fi
echo "check_identity.sh: the $count commits of $base..$tip are of $expected"
