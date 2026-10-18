"""Compare native battle recordings with cosmetic RNG isolated in test fixtures."""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mod', type=Path, required=True)
    parser.add_argument('--vanilla', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--cases', help='Compare only the named cases, in recording order')
    args = parser.parse_args()
    mod = json.loads(args.mod.read_text(encoding='utf8'))
    vanilla = json.loads(args.vanilla.read_text(encoding='utf8'))
    if not (mod['visual_rng_isolated'] and vanilla['visual_rng_isolated']):
        raise ValueError('Exact comparison requires the test-only no-mist fixture')
    if mod['seed'] != vanilla['seed'] or mod['variant'] != 'mod' or vanilla['variant'] != 'vanilla':
        raise ValueError('Mismatched fixture options')
    if [r['case'] for r in mod['outcomes']] != [r['case'] for r in vanilla['outcomes']]:
        raise ValueError('Case order must match because seeds include the case index')
    checks = []
    requested = set(args.cases.split(',')) if args.cases else None
    for left, right in zip(mod['outcomes'], vanilla['outcomes']):
        if requested is not None and left['case'] not in requested:
            continue
        for field in ('result', 'state', 'uses', 'effects', 'rng_tail', 'random_calls'):
            a, b = left[field], right[field]
            if field == 'random_calls':
                # The appended test script has a different table index in the two builds.
                # Keep operation, arguments and returned value; omit only the caller label.
                a = [event[:-1] for event in a]
                b = [event[:-1] for event in b]
            checks.append({'case': left['case'], 'field': field, 'equal': a == b})
    if not checks or (requested and requested != {c['case'] for c in checks}):
        raise ValueError('Requested cases were not recorded')
    result = {'result': 'PASS' if all(c['equal'] for c in checks) else 'FAIL',
              'checks': len(checks), 'seed': mod['seed'], 'native_graphics': True,
              'visual_rng_isolated_in_test_only': True, 'comparisons': checks}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print(json.dumps(result, ensure_ascii=False))
    if result['result'] != 'PASS':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
