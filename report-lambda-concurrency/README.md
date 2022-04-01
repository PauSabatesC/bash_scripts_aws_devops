# REPORT LAMBDA CONCURRENCY

Script to get the list of lambdas, its reserved concurrency, the quota limit of the account and the total used. 

The result is exported to a .csv so you can import on a spreadsheet.

It helps to have a better high view on which lambdas have the correct reserved concurrency and how many is left. 

## How to install and use

```sh
git clone ...
```

```sh
echo "\n#DNS EYE SCRIPT\nalias report-lambdas-concurrency="$PWD/report-lambdas-concurrency.sh"" >> ~/.bashrc && . ~/.bashrc
# (export your aws cli credentials before executing the script)
report-lambdas-concurrency
```

