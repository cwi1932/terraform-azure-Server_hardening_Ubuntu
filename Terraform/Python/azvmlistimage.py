
import subprocess
import json
import pandas as pd

cmd = subprocess.run(['az', 'vm', 'list-skus', '--location', 'eastus', '--resource-type', 'virtualMachines', '--output', 'json'], 
    capture_output=True
)

data = cmd.stdout

x=json.loads(data)
df = pd.DataFrame(x)


df1 = df[["resourceType", "locations", "name", "restrictions"]]
df_none = df1[df1["restrictions"].apply(len) == 0]

vm_size= (df_none[["name", "resourceType"]].head(20))

vm_size.to_csv("file.csv", index=False)
