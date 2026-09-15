"""Narrow corpus assertions; these do not score general image-description quality."""
import json,sys
from pathlib import Path
root=Path('/private/tmp/stillview-macos27-evidence');label=sys.argv[1]
rows={r['file']:r for r in (json.loads(x) for x in (root/f'{label}.jsonl').read_text().splitlines()) if r.get('kind')=='image'}
checks=[]
def check(name,passed,note):checks.append(dict(name=name,passed=passed,note=note))
def result(name):return rows.get(name,{}).get('result',{})
def ocr(name):return '\n'.join(result(name).get('recognizedText',[]))
check('30 successful production service outcomes',len(rows)==30 and all(r['status']=='success' for r in rows.values()),f'{len(rows)} records')
check('Receipt total survives OCR output','$19.44' in ocr('receipt-long.png'),ocr('receipt-long.png'))
check('Repeated table price preserved three times',ocr('table-repeated-values.png').count('$2.00')>=3,ocr('table-repeated-values.png'))
check('Single digit sign retained in OCR','7' in result('sign-short-number.png').get('recognizedText',[]),ocr('sign-short-number.png'))
check('CJK station sign retained','東京駅' in ocr('sign-cjk.png'),ocr('sign-cjk.png'))
check('Single CJK sign retained','水' in ocr('sign-single-cjk.png'),ocr('sign-single-cjk.png'))
check('STOP sign retained','STOP' in ocr('sign-stop.png'),ocr('sign-stop.png'))
selected_exact=all(all(line in r.get('result',{}).get('recognizedText',[]) for line in r.get('result',{}).get('selectedTextLines',[])) for r in rows.values())
check('Every selected OCR excerpt resolves to exact retained OCR',selected_exact,'Membership check only; generated prose still needs visual assessment.')
(root/f'{label}-corpus-checks.json').write_text(json.dumps(checks,indent=2,ensure_ascii=False)+'\n')
for c in checks:print(('PASS' if c['passed'] else 'FAIL')+': '+c['name'])
