# endoflifeChecker
validate EOL against endoflife.date

# possible way to run this script against all images found in a K8S cluster
Create list of images:
``` bash
kubectl --context haven-prod get pods --all-namespaces -o jsonpath="{.items[*].spec.containers[*].image}" | \
tr -s '[[:space:]]' '\n' | \
sort | \
uniq > image_eks.lst
```

run eol.sh with gnu parallel
``` bash
cat ./image_eks.lst | parallel -j 7 '(./eol.sh {}) | tee -a image_eks_eol.csv'
```