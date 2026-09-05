#!/usr/bin/env bash
set -uo pipefail
#*****************************************************************************************
# format-source.sh
#
# git pre-commit hook script that formats the source files a commit is staging
#
# What is staged is what gets formatted, and what gets written back.  A file staged in part
# keeps the part that was held back, and the copy in the working tree is only overwritten
# when it still holds exactly what was staged.  Formatting the working tree and re-adding
# it, which is what this hook used to do, silently promotes unstaged edits into the commit
# and defeats any attempt to stage a file in pieces.
#
# Author   :  Gary Ash <gary.ash@icloud.com>
# Created  :   8-Feb-2026  3:37pm
# Modified :   5-Sep-2026  5:20pm
#
# Copyright © 2026 By Gary Ash All rights reserved.
#*****************************************************************************************

readonly SWIFT_FILES='\.swift$'
readonly OBJC_FILES='\.(m|mm|pch|h|hh)$'
readonly C_FILES='\.(hpp|hxx|c|cc|cpp|cxx|cs|jav|java)$'

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pre-commit.XXXXXX")" || exit 0
trap 'rm -rf "${WORK_DIR}"' EXIT

#*****************************************************************************************
# format one file in place, by name
#
# Non-zero when no formatter claims the file or the one that does is not installed, which
# leaves the staged content exactly as the author wrote it.  The name matters: the scratch
# copy keeps the original basename so extension driven tools still recognize it.
#*****************************************************************************************
format_file() {
	local file="$1" line

	if [[ ${file} =~ ${SWIFT_FILES} ]]; then
		command -v swiftformat >/dev/null || return 1
		swiftformat --config "${HOME}/.config/.swiftformat" "${file}" &>/dev/null
	elif [[ ${file} =~ ${OBJC_FILES} ]]; then
		command -v uncrustify >/dev/null || return 1
		uncrustify -l OC+ --replace --no-backup -c "${HOME}/.config/.uncrustify" "${file}" &>/dev/null
	elif [[ ${file} =~ ${C_FILES} ]]; then
		command -v uncrustify >/dev/null || return 1
		uncrustify --replace --no-backup -c "${HOME}/.config/.uncrustify" "${file}" &>/dev/null
	else
		read -r line <"${file}" || return 1
		if [[ ${line} =~ ^\#\!.*perl ]]; then
			command -v perltidy >/dev/null || return 1
			perltidy -b -bext='/' --profile="${HOME}/.config/.perltidyrc" "${file}" &>/dev/null
		elif [[ ${line} =~ ^\#\!.*python ]]; then
			command -v black >/dev/null || return 1
			black --config "${HOME}/.config/black" --quiet "${file}" &>/dev/null
		elif [[ ${line} =~ ^\#\!.*(bash|zsh|sh)$ ]]; then
			command -v shfmt >/dev/null || return 1
			shfmt -ln bash -i 0 -s -ci -w "${file}" &>/dev/null
		else
			return 1
		fi
	fi
	return 0
}

#*****************************************************************************************
# format what the commit is actually staging
#
# The staged blob is written out to a scratch copy, formatted there, and handed back to the
# index as a new blob.  The file in the working tree follows only when it still matches the
# blob that was staged; anything else is a partially staged file, and its unstaged edits
# are its author's business, not this hook's.
#*****************************************************************************************
count=0
while IFS= read -r -d '' path; do
	entry="$(git ls-files --stage -- "${path}" 2>/dev/null)" || continue
	[[ -n ${entry} ]] || continue

	# an unmerged path has an entry per stage, leave a conflict resolution alone
	[[ ${entry} == *$'\n'* ]] && continue

	# only ordinary files carry source to format, skip symlinks and submodules
	mode="${entry%% *}"
	[[ ${mode} == 100644 || ${mode} == 100755 ]] || continue

	count=$((count + 1))
	mkdir -p "${WORK_DIR}/${count}" || continue
	staged="${WORK_DIR}/${count}/${path##*/}"

	git cat-file blob ":${path}" >"${staged}" 2>/dev/null || continue
	cp "${staged}" "${staged}.staged" || continue

	format_file "${staged}" || continue
	cmp -s "${staged}" "${staged}.staged" && continue

	hash="$(git hash-object -w -- "${staged}" 2>/dev/null)" || continue
	git update-index --cacheinfo "${mode},${hash},${path}" 2>/dev/null || continue

	if cmp -s "${staged}.staged" "${path}"; then
		cat "${staged}" >"${path}"
		git update-index -q --refresh -- "${path}" &>/dev/null
	fi
done < <(git diff --cached --name-only -z --diff-filter=ACM)

exit 0
