#!/usr/bin/env python3
import json
import sys

with open('surge-go/singbox_config.json', 'r') as f:
    config = json.load(f)

# Collect all defined tags
defined_tags = set()
for i, outbound in enumerate(config['outbounds']):
    tag = outbound.get('tag')
    if tag:
        defined_tags.add(tag)
    print(f"[{i}] type={outbound.get('type'):10s} tag={tag}")

print("\n--- Checking references ---")
for i, outbound in enumerate(config['outbounds']):
    if 'outbounds' in outbound and outbound['outbounds']:
        print(f"\n[{i}] {outbound.get('tag')} references:")
        for ref in outbound['outbounds']:
            if ref not in defined_tags:
                print(f"  ❌ {ref} NOT FOUND")
            else:
                # Find index
                for j, o in enumerate(config['outbounds']):
                    if o.get('tag') == ref:
                        if j > i:
                            print(f"  ⚠️  {ref} at [{j}] AFTER current [{i}]")
                        else:
                            print(f"  ✓  {ref} at [{j}]")
                        break
