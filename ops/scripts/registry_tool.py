#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path

import yaml


def expand(v):
    if isinstance(v, str):
        return os.path.expandvars(os.path.expanduser(v))
    return v


def load_registry(path: Path):
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict) or "gateways" not in data:
        raise SystemExit(f"Invalid registry format: {path}")
    return data


def get_gateway(registry, name):
    gateways = registry.get("gateways", {})
    if name not in gateways:
        raise SystemExit(f"Gateway not found: {name}")
    merged = dict(gateways[name] or {})
    merged["name"] = name
    return merged


def get_field(obj, field):
    cur = obj
    for p in field.split("."):
        if not isinstance(cur, dict) or p not in cur:
            raise SystemExit(f"Field not found: {field}")
        cur = cur[p]
    return cur


def main():
    parser = argparse.ArgumentParser(description="Read gateway registry")
    parser.add_argument("--registry", default=None)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_get = sub.add_parser("get")
    p_get.add_argument("--name", required=True)
    p_get.add_argument("--field", required=True)
    p_get.add_argument("--expand", action="store_true")

    p_show = sub.add_parser("show")
    p_show.add_argument("--name", required=True)
    p_show.add_argument("--expand", action="store_true")

    p_list = sub.add_parser("list")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent.parent
    registry_path = Path(args.registry) if args.registry else repo_root / "ops" / "gateway-registry.yaml"
    registry = load_registry(registry_path)

    if args.cmd == "get":
        gw = get_gateway(registry, args.name)
        value = get_field(gw, args.field)
        if args.expand:
            value = expand(value)
        if isinstance(value, (dict, list)):
            print(json.dumps(value, ensure_ascii=False))
        else:
            print(value)
        return

    if args.cmd == "show":
        gw = get_gateway(registry, args.name)
        if args.expand:
            gw = {k: expand(v) for k, v in gw.items()}
        print(json.dumps(gw, ensure_ascii=False, indent=2))
        return

    if args.cmd == "list":
        for name in registry.get("gateways", {}):
            print(name)
        return


if __name__ == "__main__":
    main()
