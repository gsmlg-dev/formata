"""Independent YAML 1.2 emitter oracle; test-only ruamel.yaml 0.18.16.

Compose typed nodes instead of constructing dictionaries: bool/int keys must
remain distinct, and no duplicate or complex keys may disappear through a
host-language dictionary conversion. Only scalar nodes use the constructor.
"""
import json
import math
import sys

import ruamel.yaml
from ruamel.yaml.nodes import MappingNode, ScalarNode, SequenceNode
from ruamel.yaml.resolver import VersionedResolver

assert ruamel.yaml.__version__ == "0.18.16", "use the pinned reference version"


class CoreResolver(VersionedResolver):
    def add_version_implicit_resolver(self, version, tag, regexp, first):
        # Filter when each document's resolver is built, including instances
        # recreated by YAML.compose when it selects the document version.
        if tag not in ("tag:yaml.org,2002:merge", "tag:yaml.org,2002:timestamp"):
            super().add_version_implicit_resolver(version, tag, regexp, first)


def core_yaml():
    parser = ruamel.yaml.YAML(typ="safe", pure=True)
    parser.version = (1, 2)
    # ruamel's default profile adds merge and timestamps even in 1.2 mode.
    # Neither is a YAML 1.2 core implicit production. Keep explicit tags and
    # all normative core resolutions; remove only these two extensions.
    parser.Resolver = CoreResolver
    return parser


yaml = core_yaml()


def typed(node):
    if node is None:
        return ["null"]
    if isinstance(node, MappingNode):
        pairs = [[typed(k), typed(v)] for k, v in node.value]
        pairs.sort(key=lambda pair: json.dumps(pair[0], ensure_ascii=False, separators=(",", ":")))
        return ["map", pairs]
    if isinstance(node, SequenceNode):
        return ["list", [typed(item) for item in node.value]]
    assert isinstance(node, ScalarNode)
    value = yaml.constructor.construct_object(node)
    if value is None:
        return ["null"]
    if isinstance(value, bool):
        return ["bool", value]
    if isinstance(value, int):
        return ["int", value]
    if isinstance(value, float):
        if math.isnan(value):
            value = "nan"
        elif math.isinf(value):
            value = "inf" if value > 0 else "-inf"
        return ["float", value]
    assert isinstance(value, str), (node.tag, type(value))
    return ["str", value]


with open(sys.argv[1], encoding="utf-8") as file:
    documents = json.load(file)
results = []
for document in documents:
    # A fresh constructor prevents per-document memoized scalar state leaking.
    yaml = core_yaml()
    results.append(typed(yaml.compose(document)))
json.dump(results, sys.stdout, ensure_ascii=True)
