"""Copy Zed's upstream release profile without importing target settings."""

import sys
import tomllib
from pathlib import Path

import tomli_w


with Path(".cargo/bundle-config.toml").open("rb") as source:
    release = tomllib.load(source)["profile"]["release"]

with Path(sys.argv[1]).open("wb") as output:
    tomli_w.dump({"profile": {"release": release}}, output)
