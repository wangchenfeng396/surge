#!/usr/bin/env python3
import json

with open('surge-go/singbox_config.json', 'r') as f:
    config = json.load(f)

# Collect all defined tags
defined_tags = set()
for outbound in config['outbounds']:
    tag = outbound.get('tag')
    if tag:
        defined_tags.add(tag)

print("Defined outbound tags:")
for tag in sorted(defined_tags):
    print(f"  - {tag}")

print("\n--- Checking rules ---")
rules = config.get('route', {}).get('rules', [])
print(f"Total rules: {len(rules)}")

for i, rule in enumerate(rules):
    outbound = rule.get('outbound')
    if outbound and outbound not in defined_tags:
        print(f"Rule [{i}]: ❌ outbound '{outbound}' NOT FOUND")
        print(f"  Rule: {rule}")
