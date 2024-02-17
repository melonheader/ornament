# ornament
A script to scan an oRNAment database with a -bed query [oRNAment database](https://rnabiology.ircm.qc.ca/oRNAment) [[1]](https://academic.oup.com/nar/article/48/D1/D166/5625539).

## Example usage
One must run the startup script to download the database and the necessary annotation.
```bash
bash startup.sh
```
Next, run the script to produce a bed file with scored binding sites of requested RBPs overlapping the query bed.
```bash
bash ornamentise -i input.bed -r CNOT4 SRSF2
```
