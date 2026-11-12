# Tests tagged :upstream_blocked assert correct behavior that currently fails
# because of a confirmed dependency bug (each test names its issue). They are
# excluded from the default run and are a release gate:
#
#     mix test --include upstream_blocked
#
ExUnit.start(exclude: [:upstream_blocked])
