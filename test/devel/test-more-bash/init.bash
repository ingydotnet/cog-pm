#!/usr/bin/env bash

set -e

export BASHLIB="`
  find $PWD -type d |
  grep -E '/(bin|lib)$' |
  xargs -n1 printf "%s:"
`"
export PATH="$BASHLIB:$PATH"
source bash+ :std
