from pathlib import Path
import json,statistics,sys
root=Path('/private/tmp/stillview-macos27-evidence');label=sys.argv[1]
rows=[json.loads(x) for x in (root/f'{label}.jsonl').read_text().splitlines()];header=rows[0];records=rows[1:]
manifest={x['file']:x for x in json.loads((root/'manifest.json').read_text())['fixtures']}
times=[x['latencySeconds'] for x in records]
lines=[f'# StillView macOS 27 Insights: {label}', '',f"- OS: {header['os']}",f"- Model: {header['modelVariant']}",f"- Context: {header['contextSize']} tokens",f"- Source hashes: `{header['sourceHashManifest']}`",f"- Availability: {header['availability']}",f"- Images: {len(records)}; successes: {sum(x['status']=='success' for x in records)}",f'- Latency: median {statistics.median(times):.2f}s; range {min(times):.2f}–{max(times):.2f}s; total {sum(times):.2f}s',f"- Method: {header['method']}", '', 'This is a local regression corpus, not a model-accuracy benchmark. All fixture images are repository marketing photos or deterministic synthetic diagrams/documents. Each genuine production-service result is below alongside expected visible features. Exact source hashes and machine-readable results are retained.', '']
for r in records:
 f=r['file'];m=manifest[f];lines += [f'## {f}', '', f"- Latency: {r['latencySeconds']:.2f}s",f"- Fixture SHA256: `{m['sha256']}`",'- Expected: '+'; '.join(m['expected_visible_features'])]
 if m['notes']:lines.append('- Fixture note: '+m['notes'])
 if r['status']=='error':lines+=['- Error: '+r['error'],''];continue
 result=r['result']
 for key,val in result.items():
  if isinstance(val,list):
   if val:lines += ['- '+key+':']+['  - '+str(v).replace('\n',' / ') for v in val]
  else:lines.append('- '+key+': '+str(val).replace('\n',' / '))
 lines.append('')
(root/f'{label}-report.md').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines[:11]))
