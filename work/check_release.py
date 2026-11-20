from pathlib import Path
import subprocess, sys
checks = ['release','today','gold_prices','tooltips_search','auction_regressions','prices','layout','ui_recovery','themes','tales','roadmap','support','seller']
for check in checks:
    subprocess.run([sys.executable, f'work/test_{check}.py'], check=True)
print(f'PASS: all {len(checks)} release checks')
