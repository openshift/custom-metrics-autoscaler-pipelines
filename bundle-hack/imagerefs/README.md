# Image Refs

These are the master images refs that renovate will bump via PR every time we have a new successful build. The contents of these files should always be the newest successful image.

The original example has them in the `update_bundle.sh` script, but we have 3 operands, and what happens is if you build them all at the same time, renovate will generate all 3 branches at the same time, and then once you merge the first operand PR you have to rebase/fix conflicts in the other branches.

TODO(jkyros): Renovate says it will rebase the PR if you click the little checkbox, but like 95% of the time it just ignores it.
