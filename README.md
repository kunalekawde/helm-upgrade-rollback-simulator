# helm-upgrade-rollback-simulator

This is a simple bash script which can be run from the vm which has access to kubernetes cluster to:
1. Follow a order of chart upgrade
2. If there is any error with helm upgrade, it will check for rollback policy.
3. If not, it continues with helm test
4. If helm test errors, it will check for rollback policy.
5. At above mentioned points, if rollback policy is checked for, it would either rollback all the upgraded charts in reverse order or just rollback the chart which failed and pause.
6. The rollback policy is to pause-on-failure or rollback-on-failure
